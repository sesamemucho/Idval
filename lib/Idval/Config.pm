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
use Idval::Logger qw(:vars idv_print chatty idv_dbg idv_warn fatal would_I_print idv_dumper);

our %vars;

=head1 NAME

Idval::Config - Handles configuration files for Idval

=head1 SYNOPSIS

    use Idval::Config;

    # Create a new config object
    $cfg = Idval::Config->new("config-file-name");

    # Merge in more configuration information
    $cfg->add_file("config-file-to-merge");

    # Make a copy (so you can merge in information without affecting the original cfg object)
    my $newcfg = $cfg->copy();

    $value = $cfg->i18n_get_single_value($context, $key-name, \%selectors, $default-value);

    $listref = $cfg->get_list_value($key-name, \%selectors, $default-value);

    ...

=head1 DESCRIPTION

Idval::Config provides a way to read configuration data for Idval
programs. It supports single values and lists, and allows these values
to be assigned conditionally. This, together with a block structure,
allows for a kind of "programming by difference".

A primary characteristic of an Idval configuration file is
concision. This comes from a reduced syntax. There are eight kinds of
lines allowed in a configuration file (see L</"FORMAT"> for complete
information).

Much of this can be seen from a short example.

   1  convert = MP3
   2  {
   3     type == ABC
   4     convert = MIDI
   5  }

Line 1 shows an assignment: "convert" gets the value "MP3". Line 2
starts a block (which is ended on line 5). Line 3 is a conditional
statement. This says that the assignments in the block will only take
effect if the value of "type" is "ABC". If this is the case, then
"convert" will get the value "MIDI". What this config fragment says in
practise is that music files will be converted to the MP3 format,
unless they are .abc files, in which case they will be converted to
MIDI.

=head1 FORMAT

Leading and trailing whitespace on a line is ignored.

=head2 Lines

=over

=item Assignments

Assignment statements have the form C<varname op value>. I<varname>
may be any sequence of non-blank characters. I<op> may be either B<=>
or B<+=>. White space on either side of I<op> will be
ignored. I<value> may be any sequence of characters (white space
included) that starts at the first non-blank character after I<op> and
continues to the end of the line. Note that white space at the end of
the line is also ignored.

Assignments made with B<=> are single-value assignments, and those
made with B<+=> create lists. You will ususally want to use
single-value assignments, such as 'type = MP3', or 'convert =
OGG'. Currently, the only times it would make sense to use list
assignments are for the variables 'provider_dir' and 'command_dir'
(See L</"VARIABLES"> for descriptions of built-in variables.

Variables are created by assigning something to them. A variable is
available for use (for instance, in a conditional) immediately.

=item Conditionals (or Selectors)

The assignment statements in any block are controlled by conditional
statements. If all the conditionals in a block are true, then the
 assignments are selected, and the variables are set. The available
 conditional operators are:

=over

=item variable == value   or    variable eq value

The block is selected if B<variable> is equal to B<value>.

=item variable != value   or    variable ne value

The block is selected if B<variable> is not equal to B<value>.

=item variable < value   or    variable lt value

The block is selected if B<variable> is less than B<value>.

=item variable > value   or    variable gt value

The block is selected if B<variable> is greater than B<value>.

=item variable <= value   or    variable le value

The block is selected if B<variable> is less than or equal to B<value>.

=item variable >= value   or    variable ge value

The block is selected if B<variable> is greater than or equal to B<value>.

=item variable has value

The block is selected if B<variable> has the string B<value> somewhere inside it.

=item variable =~ value

The block is selected if B<variable> matches the Perl regular expression B<value>.

=item variable !~ value

The block is selected if B<variable> does not match the Perl regular expression B<value>.

=item variable passes value

For this conditional, B<value> is the name of a built-in (or possibly
 user-defined) routine. The block is selected if the routine returns
 TRUE when B<variable> is passed in as an argument. This kind of
 conditional is used in L<validate> configuration files.

=item variable fails value

Similar to "passes", above, but the block is selected if the routine
 returns FALSE.

=back

=item Blank lines

Blank lines are ignored.

=item Comment lines

Lines that start with a '#', or with white space and a '#' are ignored.

=back

=head1 METHODS

=cut

sub logger_callback
{
    my $old_level = shift;
    my $new_level = shift;
    my $userdata = shift;

    print STDERR "In Config::logger_callback\n";

    $userdata->logger_changed($old_level, $new_level);
    return;
}

sub logger_changed
{
    my $self = shift;
    my $old_level = shift;
    my $new_level = shift;

    print STDERR "In Config::logger_changed, old level was $old_level, new level is $new_level\n";
    return;
}

=pod

=head2 new

    $cfg = Idval::Config->new("config-file-name");
    $cfg = Idval::Config->new("CLASS == MUSIC\nconvert = MP3\n");
    $cfg = Idval::Config->new("");

Constructor. Parses the configuration information and creates a
    subroutine used to return configuration data from queries. You can
    pass in either: a single configuration file name, or the contents
    of a configuration file (this last is used for
    testing). Idval::Config detects this immediate configuration data
    by looking for newlines, so the configuration file name may not
    contain newlines. To avoid special cases, you can create an empty
    Config object by passing in a blank configuration file name.

    To create a configuration object from more than one file, create
    one as above, then use L</add_file> as needed.

=cut

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

    my $lh = Idval::I18N->idv_get_handle() || die "Can't get language handle.";
    $self->{LH} = $lh;

    $self->{KEYNAMES} = {
        'tempfiles' => $lh->idv_getkey('config', 'tempfiles'),
    };

    $self->{INITFILES} = [];
    $self->{datadir} = Idval::Common::get_top_dir('Data');
    $self->{DEBUG} = 0;

    Idval::Logger::get_logger()->register(__PACKAGE__, \&logger_callback, $self);

    $self->{CALCULATED_VARS} = Idval::Config::Methods::return_calculated_vars();

    if ($initfile)
    {
        $self->add_file($initfile);
    }

    return;
}
=pod

=head2 copy

    my $newcfg = $cfg->copy('additional-cfg-file1', ...);

You may want to modify or add to a configuration object, but only
    temporarily. Use Idval::Config::copy to create a copy of the
    config object, which will not affect the copied configuration.

=cut
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
=pod

=head2 DEBUG

Uncomment or modify to turn on (more) debugging information.

=cut
sub DEBUG
{
    my $self = shift;

    return $self->{DEBUG};
}

# just handy for development
sub DEBUG1
{
    my $self = shift;

    #return ref $self eq 'Idval::Validate';
    return 0;
}
=pod

=head2 add_file

    $cfg->add_file('other-configuration-file');

Use add_file to merge in additional configuration information to a
    config object.

=cut
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
        $self->DEBUG1 && print STDERR "C: processing cfg file <$fname>\n";

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
    #print STDERR "subr_text is \n$subr_text\n";
    $self->{SUBR_TEXT} = $subr_text;
    $self->{SUBR} = eval $subr_text;
    if ($@)
    {
        fatal("Error converting to subr: [_1]\nsubr text is: <[_2]>\n", $@, $subr_text);
    }
    else
    {
        #print STDERR "Eval was OK\n";
    }

    $self->{JM_SUBR} = eval $just_match_subr_text;
    $self->{JM_SUBR_TEXT} = $just_match_subr_text;
    if ($@)
    {
        fatal("Error converting to jm_subr: [_1]\njm_subr text is: <[_2]>\n", $@, $just_match_subr_text);
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

    idv_dbg("looking for [_1] in [_2]", join(',', @{$tagsref}), idv_dumper($selectors, $varsref));

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

    chatty("ck_selects: returning: [_1]", idv_dumper($ar_selects, \%expanded_tags));
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
            idv_dbg("ert: for \"[_1]\", checking [_2]", $regexp_tag, idv_dumper($ert_conditional));
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
                      ($cmp_result ? "True\n" : "False\n"), $selects->{$tagname}, $op, $value);

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
    idv_dbg("pc: parts: [_1]", idv_dumper(\%parts));

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
    my $rhs = '';

    idv_dbg("In parse_vars, got [quant,_1,var,vars]\n", scalar(@vars));
    foreach my $varinfo (@vars)
    {
        my ($var, $op, $value) = @{$varinfo};
        my $previous_var = '';
        if ($value =~ m/^(.*)%([^%]+)%(.*)$/)
        {
            my $pre = (defined($1) && $1) ? 'q{' . $1 . '} . ' : '';
            my $post = (defined($3) && $3) ? ' . q{' . $3 . '}' : '';
            $previous_var = $2;
            if ($previous_var eq 'DATA')
            {
                $rhs = $pre . 'q{' . $self->{datadir} . '}' . $post;
            }
            else
            {
                $rhs = $pre . '$vars{q{' . $previous_var . '}}' . $post;
            }
        }
        else
        {
            $rhs = 'q{' . $value . '}';
        }

        if ($op eq '=')
        {
            #push(@results, 'print STDERR "vars{' . $previous_var . '} is: $vars{q{' . $previous_var . '}}\n";') if $previous_var;
            if ($previous_var && ($previous_var ne 'DATA'))
            {
                push(@results,
                     'print STDERR "vars{' . $previous_var . '} is: undefined\n" unless($vars{q{' . $previous_var . '}});');
            }
            push(@results, '$vars{q{' . $var . '}} = ' . $rhs . ';');
            #push(@results, 'print STDERR "keys: ", join(", ", keys(%{$ar_selects}), keys(%{$expanded_tags})), "\n";');
        }
        else                    # op is '+='
        {
            push(@results, '$vars{q{' . $var . '}} = exists($vars{q{' . $var . '}}) ? add_to_list($vars{q{' . $var . '}}, ' . $rhs .') : ' . $rhs .';');
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
=pod

=head2 config_to_subr

Internal routine.

Turn a config file into a subroutine of if-statements and
assignments. Whatever is set at the end of the subroutine is the
result of matching the config file against the selectors.

 The flow is:
   accumulate conditional statements
   accumulate assignment statements
   if we see a '{' or a '}', we are entering or leaving an if-block,
     so write out the previous if(conditional){set variables} block
     as appropriate, and clear the accumulators.

=cut
sub config_to_subr
{
    my $self = shift;
    my $cfg_text = shift;
    my $cmp_regex = Idval::Select::get_cmp_regex();
    my $assign_regex = Idval::Select::get_assign_regex();

    $self->DEBUG1 && print STDERR "C: config text is: <$cfg_text>\n";
    my @conditionals = ();
    my @vars = ();
    my %seen_conds;
    my $block_text = '';

    $self->{LEVEL} = 1;
    $self->{INDENT} = '  ';

    my $subr = "sub\n{\n#use warnings FATAL => qw(uninitialized);\n  my \$selects = shift;\n  my \%vars;\n  my \$ar_selects;\n  my \$expanded_tags;\n  my \$rg_matched_tags = [];\n\n";
    my $just_match_subr = "sub\n{\n  my \$selects = shift;\n  my \$ar_selects;\n  my \$expanded_tags;\n  my \$rg_matched_tags = [];\n\n";
    $subr .= $self->current_indent() . 'print STDERR "from SUBR, selects: ", Dumper($selects);' . "\n" if would_I_print($L_DEBUG);
    $just_match_subr .= $self->current_indent() . 'print STDERR "from SUBR, selects: ", Dumper($selects);' . "\n" if would_I_print($L_DEBUG);
    foreach my $line (split(/\n|\r\n|\r/, $cfg_text))
    {
        $self->DEBUG1 && print STDERR "C: processing <$line>\n";
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

            @conditionals = ();            @vars = ();
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
            $self->DEBUG1 && print STDERR "C: found assign regex: $name, $op, $value\n";
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
=pod

=head2 get_single_value

    $value = $cfg->get_single_value('variable-name', \%selectors, $default);

Get the value of the variable named 'variable-name', given a set of
    conditional expressions in %selectors. If there is no
    'variable-name' selected, use $default as the value. The default
    value of $default is ''; If 'variable-name' is actually a list,
    return the first item in the list.

=cut
sub get_single_value
{
    my $self = shift;
    my $key = shift;
    my $selects = shift;
    my $default = shift || '';

    my $value = $self->get_value($key, $selects, $default);

    return ref $value eq 'ARRAY' ? ${$value}[0] : $value;
}
=pod

=head2 i18n_get_single_value

    $value = $cfg->i18n_get_single_value("context", 'variable-name', \%selectors, $default);

Internationalize 'variable-name' according to "context" before getting
    the value. See <L/i18n_get_value>.

=cut
sub i18n_get_single_value
{
    my $self = shift;
    my $context = shift;
    my $key = shift;
    my $selects = shift;
    my $default = shift || '';

    my $value = $self->i18n_get_value($context, $key, $selects, $default);

    return ref $value eq 'ARRAY' ? ${$value}[0] : $value;
}
=pod

=head2 get_list_value

    [$value] = $cfg->get_list_value('variable-name', \%selectors, $default);

Get the value of the variable named 'variable-name' as a list reference, given a set of
    conditional expressions in %selectors. If there is no
    'variable-name' selected, use [$default] as the value. The default
    value of $default is ['']; If 'variable-name' is actually a single
    value, return the value as a list reference.

=cut
sub get_list_value
{
    my $self = shift;
    my $key = shift;
    my $selects = shift;
    my $default = shift || '';

    my $value = $self->get_value($key, $selects, $default);

    return ref $value eq 'ARRAY' ? $value : [$value];
}
=pod

=head2 i18n_get_list_value

    [$value] = $cfg->i18n_get_list_value("context", 'variable-name', \%selectors, $default);

Internationalize 'variable-name' according to "context" before getting
    the value. See <L/i18n_get_value>.

=cut
sub i18n_get_list_value
{
    my $self = shift;
    my $context = shift;
    my $key = shift;
    my $selects = shift;
    my $default = shift || '';

    my $value = $self->i18n_get_value($context, $key, $selects, $default);

    return ref $value eq 'ARRAY' ? $value : [$value];
}

sub get_value
{
    my $self = shift;
    my $key = shift;
    my $selects = shift;
    my $default = shift || '';

    #$cfg_dbg = ($key eq 'sync_dest');
    idv_dbg("In get_value with key \"[_1]\"\n", $key); ##debug1
    my $vars = $self->merge_blocks($selects);
    idv_dbg("get_value: list result for \"[_1]\" is: [_2]", $key, idv_dumper($vars->{$key})); ##Dumper
    return defined $vars->{$key} ? $vars->{$key} : $default;
}
=pod

=head2 i18n_get_value

Automatically internationalize the variable name according to a
    context, using the C<idv_getkey> routine (See L<I18N>). The
    selector hash is also internationalized, I<EXCEPT> if the selector
    hash is an Idval::Record object, since that will already be in the
    user's locale.

=cut
sub i18n_get_value
{
    my $self = shift;
    my $context = shift;
    my $key = shift;
    my $selects = shift;
    my $default = shift || '';

    my $i18n_key = $self->{LH}->idv_getkey($context, $key);
    my %i18n_selects = ();
    if ($selects)
    {
        if (ref $selects eq 'HASH') # In particular, don't translate Idval::Record
        {
            my $i18n_s_key;
            my $i18n_s_value;
            while (my ($s_key, $s_value) = each %{$selects})
            {
                $i18n_s_key = $self->{LH}->idv_getkey($context, $s_key);
                $i18n_s_value = $self->{LH}->idv_getkey($context, $s_value);
                $i18n_selects{$i18n_s_key} = $i18n_s_value;
            }
        }
        else
        {
            %i18n_selects = %{$selects};
        }
    }

    #$cfg_dbg = ($key eq 'sync_dest');
    idv_dbg("In i18n_get_value with key \"[_1]\", default is: \"[_2]\"\n", $i18n_key, $default); ##debug1
    my $vars = $self->merge_blocks(\%i18n_selects);
    #print STDERR "i18n_get_value: selects, merge_blocks: ", Dumper(\%i18n_selects), Dumper($vars);
    idv_dbg("i18n_get_value: list result for \"[_1]\" is: [_2]", $i18n_key, idv_dumper($vars->{$i18n_key})); ##Dumper
    return defined $vars->{$i18n_key} ? $vars->{$i18n_key} : $default;
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

$method_descriptions{__file_time} = "UNIX time stamp for this file (seconds since 1/1/1970)";
sub get_file_time
{
    my $selectors = shift;

    fatal("No filename in selectors") unless exists $selectors->{FILE};
    return [Idval::FileIO::idv_get_mtime($selectors->{FILE})];
}

$method_descriptions{__file_age} = "how old the file is, in hours";
sub get_file_age
{
    my $selectors = shift;
    my $result = int((time - Idval::FileIO::idv_get_mtime($selectors->{FILE})) / 3600);
    print STDERR "Hello from file_age, checking $selectors->{FILE} result is $result\n";
    return [int((time - Idval::FileIO::idv_get_mtime($selectors->{FILE})) / 3600)];
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

    return \%cvlist;
}

1;
