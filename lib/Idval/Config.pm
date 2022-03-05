package Idval::Config;

# Copyright 2008 Bob Forgey <rforgey@grumpydogconsulting.com>

# This file is part of Idval.

# Idval is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# Idval is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with Idval.  If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;
use Data::Dumper;
use English '-no_match_vars';
use Memoize;
use File::Temp;
use List::Util qw(first);

use Idval::I18N;
use Idval::Common;
use Idval::Select;
use Idval::FileIO;
use Idval::Logger qw(:vars idv_print chatty idv_dbg idv_warn fatal would_I_print);

our %vars;

sub new
{
    my $class = shift;
    my $self = {};
    bless($self, ref($class) || $class);
    $self->{ALLOW_KEY_REGEXPS} = 0; # Validate.pm will be different
    $self->_init(@_);
    return $self;
}

sub _init
{
    my $self = shift;
    my $initfile = shift;

    my $lh = Idval::I18N->get_handle() || die "Config: Can't get a language handle!";

    $self->{KEYNAMES} = {
        'tempfiles' => $lh->idv_getkey('config', 'tempfiles'),
    };

    $self->{INITFILES} = [];
    $self->{datadir} = Idval::Common::get_top_dir('Data');
    $self->{DEBUG} = 0;

    $self->{CALCULATED_VARS} = Idval::Config::Methods::return_calculated_vars();

    if ($initfile)
    {
        $self->add_file($initfile);
    }

    return;
}

sub copy
{
    my $self = shift;
    my @initfiles = @{$self->{INITFILES}};
    my $firstfile = shift @initfiles;
    my $newconfig = Idval::Config->new($firstfile);
    foreach my $initfile (@initfiles)
    {
        $newconfig->add_file($initfile);
    }

    return $newconfig;
}

sub add_file
{
    my $self = shift;
    my $initfile = shift;

    # Is this immediate data?
    if ($initfile =~ m/\n/)
    {
        my $fh = new File::Temp(UNLINK => 0);
        my $fname = $fh->filename;
        print $fh $initfile;
        $fh->close();
        $initfile = $fname;
        my $tempfiles = Idval::Common::get_common_object('tempfiles');
        push(@{$tempfiles}, $fname);
    }

    return unless $initfile;      # Blank input file names are OK... Just don't do anything.
    push(@{$self->{INITFILES}}, $initfile);
    fatal("Need a file") unless @{$self->{INITFILES}}; # We do need at least one config file


    my $text = '';
    my $fh;

    foreach my $fname (@{$self->{INITFILES}})
    {

        if ($fname =~ m|^/tmp/|)
        {
            $fh = IO::File->new($fname, '<');
        }
        else
        {


            $fh = Idval::FileIO->new($fname, "r") || 
                fatal("Can't open \"[_1]\" for reading: [_2] in [_3] line([_4])", $fname, $!, __PACKAGE__, __LINE__);
        }

        $text .= do { local $/ = undef; <$fh> };
        $fh->close();

    }

    my ($subr_text, $just_match_subr_text) = $self->config_to_subr($text);
    $self->{SUBR} = eval $subr_text;
    $self->{SUBR_TEXT} = $subr_text;
    if ($@)
    {
        print STDERR "Error converting to subr: $@\nsubr text is: <$subr_text>\n";
        exit 1;
    }
    else
    {
        #print STDERR "Eval was OK\n";
    }

    $self->{JM_SUBR} = eval $just_match_subr_text;
    $self->{JM_SUBR_TEXT} = $just_match_subr_text;
    if ($@)
    {
        print STDERR "Error converting to jm_subr: $@\njm_subr text is: <$just_match_subr_text>\n";
        exit 1;
    }
    else
    {
        #print STDERR "Eval was OK\n";
    }

    return;
}

sub get_cmp_func
{
    my $cmp_func_name = shift;
    my $cmp_func;

    no strict 'refs';
    eval { $cmp_func = \&$cmp_func_name; };
    use strict;

    #print STDERR "get_cmp_func: from \"$cmp_func_name\", got $cmp_func\n";
    return $cmp_func;
}

sub ck_selects
{
    my $selectors = shift;
    my $varsref = shift;
    my $tagsref = shift;        # What we're looking to use

    my %expanded_tags;          # For regexp selectors
    my %complete_tag_list;
    my $subr_var;

    idv_dbg("looking for [_1] in [_2]", join(',', @{$tagsref}), Dumper($selectors, $varsref));

    # If the tag is a regexp expression, figure out the tags it
    # matches and store the results in %expanded_tags.
    # Also, store the newly-discovered tags in %complete_tag_list for later.
    my @new_tags;
    foreach my $tag (@{$tagsref})
    {
        #print STDERR "ck: looking at <$tag>\n";
        if ($tag =~ m/\W/)
        {
            @new_tags = grep(/^$tag$/, keys %{$selectors});
            #print STDERR "ck: for <$tag>, exp tags are: ", join(':', @new_tags), "\n";
            $expanded_tags{$tag} = \@new_tags;
        }
    }

    # Then, assemble a pared-down selector hash in which all selector values are array refs
    my $ar_selects;
    my $valref;
    foreach my $tag (@{$tagsref})
    {
        if (exists($selectors->{$tag}))
        {
            $valref = $selectors->{$tag};
            $ar_selects->{$tag} = ref $valref eq 'ARRAY' ? $valref : [$valref];
        }
        if (exists($varsref->{$tag}))
        {
            $valref = $varsref->{$tag};
            $ar_selects->{$tag} = ref $valref eq 'ARRAY' ? $valref : [$valref];
        }
    }
#     foreach my $tag (keys %{$selectors})
#     {
#         $valref = $selectors->{$tag};
#         $ar_selects->{$tag} = ref $valref eq 'ARRAY' ? $valref : [$valref];
#     }

#     foreach my $tag (keys %{$varsref})
#     {
#         $valref = $varsref->{$tag};
#         $ar_selects->{$tag} = ref $valref eq 'ARRAY' ? $valref : [$valref];
#     }

    chatty("ck_selects: returning: [_1]", Dumper($ar_selects, \%expanded_tags));
    return ($ar_selects, \%expanded_tags);
}

# Regexp tags are evaluated with ORs
sub evaluate_regexp_tags
{
    my $selects = shift;
    my $expanded_tags = shift;
    my $parts = shift;

    my $cmp_result;
    my $cmp_func;
    my $retval = 0;
    my @matching_tags = ();

    #print STDERR "ert: selects, expanded_tags, parts: ", Dumper($selects, $expanded_tags, $parts);
    foreach my $regexp_tag (keys %{$expanded_tags})
    {
        foreach my $ert_conditional (@{$parts->{$regexp_tag}})
        {
            idv_dbg("ert: for \"[_1]\", checking [_2]", $regexp_tag, Dumper($ert_conditional));
            my ($cmp_name, $op, $value) = @{$ert_conditional};
            $cmp_func = get_cmp_func($cmp_name);

            foreach my $tagname (@{$expanded_tags->{$regexp_tag}})
            {
                if ($op eq 'passes' or $op eq 'fails')
                {
                    $cmp_result = &$cmp_func($selects, $tagname, $value);
                }
                else
                {
                    # BOGUS! It's time to convert selects to always be array ref vars XXX
                    my $var_ref = ref $selects->{$tagname} eq 'ARRAY' ? $selects->{$tagname} : [$selects->{$tagname}];
                    $cmp_result = &$cmp_func($var_ref, $value);
                }
                idv_dbg("Comparing \"selector list\" \"[_1]\" \"[_2]\" \"[_3]\" resulted in " .
                      $cmp_result ? "True\n" : "False\n", $selects->{$tagname}, $op, $value);

                push(@matching_tags, $tagname) if $cmp_result;
            }
        }
    }

    return @matching_tags ? [sort @matching_tags] : 0;
}

sub parse_conditionals
{
    my $self = shift;
    my @conds = @_;
    my @results = ();
    my $cmp_func;
    my %parts;

    return '' unless @conds;
    my $is_regexp = 0;
    my $ci = $self->current_indent();
    my $ciif = $ci . '    ';
    my $result = "${ci}if (\n$ciif";
    foreach my $condinfo (@conds)
    {
        my ($var, $op, $value) = @{$condinfo};
        $cmp_func = Idval::Select::get_compare_function_name($op, $value);
        push(@{$parts{$var}}, [$cmp_func, $op, $value]);
    }
    idv_dbg("pc: parts: [_1]", Dumper(\%parts));

    push(@results, "((\$ar_selects, \$expanded_tags) = ck_selects(\$selects, \\\%vars, [qw{" . join(' ', keys %parts) . '}]))');
    # If there are any regexp keys, handle them here
    if (grep(/\W/, keys %parts))
    {
        my $ert_cmd = '($rg_matched_tags = evaluate_regexp_tags($selects, $expanded_tags, ' . '{ ';
        foreach my $rt (grep(/\W/, keys %parts))
        {
            $ert_cmd .= "q{$rt} => [";
            foreach my $rt_conditionals (@{$parts{$rt}})
            {
                my ($cmp_func, $op, $value) = @{$rt_conditionals};
            
                $ert_cmd .= "[q{$cmp_func}, q{$op}, q{$value}], ";
            }
            $ert_cmd .= "],";
        }
        $ert_cmd .= '}))';

        push(@results, $ert_cmd);
    }

    foreach my $item (keys %parts)
    {
        # If there are regexp keys, they are handled in 'evaluate_regexp_tags()'
        next if $item =~ m/\W/;
        my ($fname, $op, $value) = @{${$parts{$item}}[0]};
        if ($op eq 'passes' or $op eq 'fails')
        {
            push(@results, "$fname(\$selects, q{$item}, q{$value})");
        }
        elsif (exists($self->{CALCULATED_VARS}->{$item}))
        {
            push(@results, "$fname($self->{CALCULATED_VARS}->{$item}->{NAME}(\$selects), q{$value})");
        }
        else
        {
            push(@results, "(exists(\$ar_selects->{$item}) && $fname(\$ar_selects->{$item}, q{$value}))");
        }
    }

    $result .= join(" &&\n$ciif", @results) . "\n${ci}   )\n";
    #print STDERR "pc: returning <$result>\n";
    return $result;
}

sub add_to_list
{
    my $maybe_list = shift;
    my $item = shift;
    my $result;

    if(ref $maybe_list eq 'ARRAY')
    {
        $result = [@{$maybe_list}, $item];
    }
    else
    {
        $result = [$maybe_list, $item];
    }

    return $result;
}

sub parse_vars
{
    my $self = shift;
    my @vars = @_;
    my @results = ();

    idv_dbg("In parse_vars, got [quant,_1,var,vars]\n", scalar(@vars));
    foreach my $varinfo (@vars)
    {
        my ($var, $op, $value) = @{$varinfo};
        $value =~ s/\%DATA\%/$self->{datadir}/gx;

        if ($op eq '=')
        {
            push(@results, '$vars{q{' . $var . '}} = q{' . $value . '};');
            #push(@results, 'print STDERR "keys: ", join(", ", keys(%{$ar_selects}), keys(%{$expanded_tags})), "\n";');
        }
        else                    # op is '+='
        {
            push(@results, '$vars{q{' . $var . '}} = exists($vars{q{' . $var . '}}) ? add_to_list($vars{q{' . $var . '}}, q{' . $value . '}) : q{' . $value . '};');
        }
    }

    return @results;
}

sub current_indent
{
    my $self = shift;

    return $self->{INDENT} x $self->{LEVEL};
}

sub indent_lines
{
    my $self = shift;
    my $ci = $self->current_indent();

    return $ci . join("\n$ci", @_) . "\n";
}

sub into
{
    my $self = shift;
    my $retval = $self->current_indent() . "{\n";
    $self->{LEVEL}++;

    return $retval;
}

sub out_of
{
    my $self = shift;
    $self->{LEVEL}--;
    my $retval = $self->{INDENT} x $self->{LEVEL} . "1;}\n";

    return $retval;
}

sub config_to_subr
{
    my $self = shift;
    my $cfg_text = shift;
    my $cmp_regex = Idval::Select::get_cmp_regex();
    my $assign_regex = Idval::Select::get_assign_regex();

    my @conditionals = ();
    my @vars = ();
    my %seen_conds;
    my $block_text = '';

    $self->{LEVEL} = 1;
    $self->{INDENT} = '  ';

    my $subr = "sub\n{\n  my \$selects = shift;\n  my \%vars;\n  my \$ar_selects;\n  my \$expanded_tags;\n  my \$rg_matched_tags = [];\n\n";
    my $just_match_subr = "sub\n{\n  my \$selects = shift;\n  my \$ar_selects;\n  my \$expanded_tags;\n  my \$rg_matched_tags = [];\n\n";
    $subr .= $self->current_indent() . 'print STDERR "from SUBR, selects: ", Dumper($selects);' . "\n" if would_I_print($L_DEBUG);
    $just_match_subr .= $self->current_indent() . 'print STDERR "from SUBR, selects: ", Dumper($selects);' . "\n" if would_I_print($L_DEBUG);
    foreach my $line (split(/\n|\r\n|\r/, $cfg_text))
    {
        #print STDERR "C: processing <$line>\n";
        $block_text .= $line . "\n";
        $line =~ /^\s*{\s*$/ and do {
            my $pc = $self->parse_conditionals(@conditionals);
            $subr .= $pc;
            $just_match_subr .= $pc;
            my @var_results = $self->parse_vars(@vars);

            if (@var_results)
            {
                $subr .= $self->into();
                $subr .= $self->indent_lines(@var_results);
                $subr .= $self->out_of();
            }
            if (@conditionals)
            {
                $just_match_subr .= $self->into();
                $just_match_subr .= $self->indent_lines('return 1;');
                $just_match_subr .= $self->out_of();
            }

            $subr .= $self->into();
            $just_match_subr .= $self->into();

            @conditionals = ();
            @vars = ();
            %seen_conds = ();
            $block_text = '';
            next;
        };

        $line =~ /^\s*}\s*$/ and do {
            my $pc = $self->parse_conditionals(@conditionals);
            $subr .= $pc;
            $just_match_subr .= $pc;
            my @var_results = $self->parse_vars(@vars);
            if (@var_results)
            {
                $subr .= $self->into();
                $subr .= $self->indent_lines(@var_results);
                $subr .= $self->out_of();
            }
            if (@conditionals)
            {
                $just_match_subr .= $self->into();
                $just_match_subr .= $self->indent_lines('return 1;');
                $just_match_subr .= $self->out_of();
            }
            $subr .= $self->out_of();
            $just_match_subr .= $self->out_of();

            @conditionals = ();
            @vars = ();
            %seen_conds = ();
            $block_text = '';
            next;
        };

        $line =~ /^\s*(#.*)$/ and do {
            next;
        };

        $line =~ m/^\s*$/ and do {
            next;
        };

        # Any { or } that gets here is an error
        $line =~ m/[{}]/ and do {
            fatal("Any '{' or '}' must be on a line by itself: <[_1]>\n", $line);
        };

        $line =~ m{^\s*(\S+)\s*($cmp_regex)(.*)\s*$}imx and do {
            my $name = $1;
            my $op = $2;
            my $value = $3;
            $op =~ s/^\s+//;
            $op =~ s/\s+$//;
            fatal("Conditional variable \"[_1]\" was already used in this block:\n{\n[_2]}\n", $name, $block_text) if exists($seen_conds{$name});
            $seen_conds{$name} = 1;
            push(@conditionals, [$name, $op, $value]);
            next;
        };

        $line =~ m{^\s*(\S+)\s*($assign_regex)(.*)\s*$}imx and do {
            my $name = $1;
            my $op = $2;
            my $value = $3;
            $op =~ s/^\s+//;
            $op =~ s/\s+$//;
            push(@vars, [$name, $op, $value]);
            next;
        };


        idv_warn("Unrecognized input line <[_1]>\n", $line);
    }

    my @var_results = $self->parse_vars(@vars);
    if (@var_results)
    {
        $subr .= $self->into();
        $subr .= $self->indent_lines(@var_results);
        $subr .= $self->out_of();
    }

    $subr .= $self->current_indent() . 'print STDERR "from SUBR, vars: ", Dumper(\%vars);' . "\n" if would_I_print($L_DEBUG);
    $subr .= $self->current_indent() . 'return \%vars;' . "\n}\n";

    $just_match_subr .= $self->current_indent() . 'return 0;' . "\n}\n";
    idv_dbg("returning <\n[_1]\n>\n", $subr);
    idv_dbg("returning just_match: <\n[_1]\n>\n", $just_match_subr);
    return ($subr, $just_match_subr);
}

sub merge_blocks
{
    my $self = shift;
    my $selects = shift;
    my $subr = $self->{SUBR};

    my $vars = &$subr($selects);

    #print STDERR "vars is: ", Dumper($vars);

    return $vars;
}

sub get_single_value
{
    my $self = shift;
    my $key = shift;
    my $selects = shift;
    my $default = shift || '';

    my $value = $self->get_value($key, $selects, $default);

    return ref $value eq 'ARRAY' ? ${$value}[0] : $value;
}

sub get_list_value
{
    my $self = shift;
    my $key = shift;
    my $selects = shift;
    my $default = shift || '';

    my $value = $self->get_value($key, $selects, $default);

    return ref $value eq 'ARRAY' ? $value : [$value];
}

sub get_value
{
    my $self = shift;
    my $key = shift;
    my $selects = shift;
    my $default = shift || '';

    #$cfg_dbg = ($key eq 'sync_dest');
    idv_dbg("In get_single_value with key \"[_1]\"\n", $key); ##debug1
    my $vars = $self->merge_blocks($selects);
    #idv_dbg("get_single_value: list result for \"[_1]\" is: [_2]", $key, Dumper($vars->{$key})); ##Dumper
    return defined $vars->{$key} ? $vars->{$key} : $default;
}

sub value_exists
{
    my $self = shift;
    my $key = shift;
    my $selects = shift;

    my $vars = $self->merge_blocks($selects);
    return defined($vars->{$key});
}

sub selectors_matched
{
    my $self = shift;
    my $selects = shift;
    my $subr = $self->{JM_SUBR};

    return &$subr($selects);
}

package Idval::Config::Methods;

use strict;
use Config;

use Idval::Logger qw(fatal);
use Idval::FileIO;

our %method_descriptions;

$method_descriptions{__system_type} = "desc for get_system_type";
sub get_system_type
{
    return [$Config{osname}];
}

$method_descriptions{__file_time} = "desc for get_file_time";
sub get_file_time
{
    my $selectors = shift;

    fatal("No filename in selectors") unless exists $selectors->{FILE};
    return [Idval::FileIO::idv_get_mtime($selectors->{FILE})];
}

$method_descriptions{__file_age} = "desc for get_file_age";
sub get_file_age
{
    my $selectors = shift;
    return [time - Idval::FileIO::idv_get_mtime($selectors->{FILE})];
}

sub return_calculated_vars
{
    my %cvlist;
    my $fname;

    foreach my $method (keys %Idval::Config::Methods::)
    {
        if ($method =~ m/^get_/)
        {
            ($fname = $method) =~ s/^get_/__/;

            $cvlist{$fname}->{FUNC} = $Idval::Config::Methods::{$method};
            $cvlist{$fname}->{NAME} = 'Idval::Config::Methods::' . $method;
            $cvlist{$fname}->{DESC} = $method_descriptions{$fname};
        }
    }

#     $cvlist{__file_time}->{FUNC} = \&Idval::Config::Methods::get_file_time;
#     $cvlist{__file_time}->{NAME} = 'Idval::Config::Methods::get_file_time';
#     $cvlist{__file_time}->{DESC} = 'description of Idval::Config::Methods::get_file_time';

#     $cvlist{__file_age}->{FUNC} = \&Idval::Config::Methods::get_file_age;
#     $cvlist{__file_age}->{NAME} = 'Idval::Config::Methods::get_file_age';
#     $cvlist{__file_age}->{DESC} = 'description of Idval::Config::Methods::get_file_age';

    return \%cvlist;
}

1;
