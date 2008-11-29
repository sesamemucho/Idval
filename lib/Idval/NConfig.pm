package Idval::NConfig;

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

use Idval::Common;
use Idval::Select;
use Idval::FileIO;
use Idval::Logger qw(idv_print chatty idv_dbg idv_warn fatal);

# my $xml_req_status = eval {require XML::Simple};
# my $xml_req_msg = !defined($xml_req_status) ? "$!" :
#     $xml_req_status == 0 ? "$@" :
#     "Load OK";

# if ($xml_req_msg ne 'Load OK')
# {
#     print STDERR "Oops; let's try again for XML::Simple\n";
#     use lib Idval::Common::get_top_dir('lib/perl');

#     $xml_req_status = eval {require XML::Simple};
#     $xml_req_msg = 'Load OK' if (defined($xml_req_status) && ($xml_req_status != 0));
# }

# fatal("Need XML support (via XML::Simple)") unless $xml_req_msg eq 'Load OK';

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

    $self->{INITFILES} = [];
    $self->{datadir} = Idval::Common::get_top_dir('Data');
    $self->{HAS_YAML_SUPPORT} = 0;

    if ($initfile)
    {
        $self->add_file($initfile);
    }

#     $self->{DEF_VARS} = $self->merge_blocks({config_group => 'idval_calculated_variables'});
#     foreach my $key (keys %{$self->{DEF_VARS}})
#     {
#         delete $self->{DEF_VARS}->{$key} unless $key =~ m/^__/;
#     }

    #chatty("Calculated variables are: ", Dumper($self->{DEF_VARS}));
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


            $fh = Idval::FileIO->new($fname, "r") || fatal("Can't open \"$fname\" for reading: $! in " . __PACKAGE__ . " line(" . __LINE__ . ")");
        }

        $text .= do { local $/ = undef; <$fh> };
        $fh->close();

    }

    my $subr_text = $self->config_to_subr($text);
    $self->{SUBR} = eval $subr_text;
    if ($@)
    {
        print STDERR "Error converting to subr: $@\nsubr text is: <$subr_text>\n";
        exit 1;
    }
#     my $xmltext = "<config>\n";
#     my $text = '';
#     my $fh;

#     foreach my $fname (@{$self->{INITFILES}})
#     {

#         if ($fname =~ m|^/tmp/|)
#         {
#             $fh = IO::File->new($fname, '<');
#         }
#         else
#         {


#             $fh = Idval::FileIO->new($fname, "r") || fatal("Can't open \"$fname\" for reading: $! in " . __PACKAGE__ . " line(" . __LINE__ . ")");
#         }

#         $text = do { local $/ = undef; <$fh> };
#         $fh->close();

#         if ($fname =~ m/tmp/)
#         {
#             #print "For \"$fname\", text is: \"$text\"\n";
#         }

#         if ($fname =~ m/\.xml$/i)
#         {
#             $text =~ s|\A.*?<config>||i;
#             $text =~ s|</config>.*?\z||i;
#             $xmltext .= $text;
#         }
#         elsif ($fname =~ m/\.yml$/i)
#         {
#             if ($self->{HAS_YAML_SUPPORT})
#             {
#                 my $c = YAML::Tiny->read_string($text);
#                 my $hr = $$c[1];
#                 my $data = XMLout($hr);
#                 $data =~ s|\A.*?<opt>||i;
#                 $data =~ s|</opt>.*?\z||i;
#                 $xmltext .= $data;
#             }
#             else
#             {
#                 fatal("This installation of idv does not have YAML support.");
#             }
#         }
#         else # Must be a idv-style config file
#         {
#             $xmltext .= $self->config_to_xml($text);
#         }
#     }

#     $xmltext .= "</config>\n";
#     #eval { $self->{TREE} = XML::Simple::XMLin($xmltext, keyattr => {select=>'name'}, forcearray => ['select']); };
#     $@ = '';
#     my $xmlin = XML::Simple->new();             # Work-around for DProf bug (rt 58446)
#     eval { $self->{TREE} = $xmlin->XMLin($xmltext, forcearray => ['select', 'name']); };
#     if ($@)
#     {
#         idv_print("Error from XML conversion: $@\n");
#         my ($linenum, $col, $byte) = ($@ =~ m/ line (\d+), column (\d+), byte (\d+)/);
#         $linenum = 0 unless (defined($linenum) && $linenum);
#         my $i = 1;
#         foreach my $line (split("\n", $xmltext))
#         {
#             printf "%3d: %s\n", $i, $line;
#             if ($i == $linenum)
#             {
#                 print '.....' . '.' x ($col - 1) . "^\n";
#             }

#             $i++;
#         }
#         print "\n\n";
#         fatal("XML conversion error");
#     }

#     $self->{XMLTEXT} = $xmltext; # In case someone wants to see it later
#     $self->{PRETTY} = $xmlin->XMLout($self->{TREE},
#                                      NoAttr => 1,
#                                      KeepRoot => 1,
#         );

# #     {
# #         print "xmltext: ", $self->{XMLTEXT};
# #         print "\n\n\n";
# #         print "XML: ", $self->{PRETTY};
# #         print "\n\n\n";
# #         print "TREE: ", Dumper($self->{TREE});
# #     }

    return;
}

# sub config_to_xml
# {
#     my $self = shift;
#     my $cfg_text = shift;
#     my $xml = '';
#     my $cmp_regex = Idval::Select::get_cmp_regex();
#     my $assign_regex = Idval::Select::get_assign_regex();
#     foreach my $line (split(/\n|\r\n|\r/, $cfg_text))
#     {
#         #print "Looking at: <$line>\n";

#         $line =~ /^\s*{\s*$/ and do {
#             $xml .= "<group>\n";
#             next;
#         };

#         $line =~ /^\s*}\s*$/ and do {
#             $xml .= "</group>\n";
#             next;
#         };

#         $line =~ /^\s*(#.*)$/ and do {
#             $xml .= "<!-- $1 -->\n";
#             next;
#         };

#         $line =~ m/^\s*$/ and do {
#             next;
#         };

#         #$line =~ m{^\s*([%[:alnum:]][\w%-]*)($cmp_regex)(.*)\s*$}imx and do {
#         $line =~ m{^\s*(\S+)\s*($cmp_regex)(.*)\s*$}imx and do {
#             my $name = $1;
#             my $op = $2;
#             my $value = $3;
#             $op =~ s/^\s+//;
#             $op =~ s/\s+$//;
#             $op =~ s/>/\&gt;/;
#             $op =~ s/</\&lt;/;
#             $xml .= "<select>\n<name>$name</name>\n<op>$op</op>\n<value>$value</value>\n</select>\n";
#             next;
#         };

#         #$line =~ m{^\s*([%[:alnum:]][\w%-]*)($assign_regex)(.*)\s*$}imx and do {
#         $line =~ m{^\s*(\S+)\s*($assign_regex)(.*)\s*$}imx and do {
#             my $name = $1;
#             my $op = $2;
#             $op =~ s/>/\&gt;/;
#             $op =~ s/</\&lt;/;
#             my $value = $3;
#             if ($op =~ m/\+\=/)
#             {
#                 $xml .= "<$name append=\"1\">$value</$name>\n";
#             }
#             else
#             {
#                 $xml .= "<$name>$value</$name>\n";
#             }
#             next;
#         };


#         idv_warn("Unrecognized input line <$line>\n");
#     }

#     return $xml;
# }

sub ck_selects
{
    my $selectors = shift;
    my $varsref = shift;
    my $tagsref = shift;        # What we're looking to use

    # First, make sure that all the tag names in tagsref exist in the
    # selectors or in the variables already defined
    return if (first { !(exists($selectors->{$_}) || exists($varsref->{$_})) } @{$tagsref});

     # Then, assemble a pared-down selector hash in which all selector values are array refs
    my $ar_selects;
    my $valref;
    foreach my $tag (@{$tagsref})
    {
        # The value must be either in selectors or in vars
        $valref = exists $selectors->{$tag} ? $selectors->{$tag} : $varsref->{$tag};
        $ar_selects->{$tag} = ref $valref eq 'ARRAY' ? $valref : [$valref];
    }

    return $ar_selects;
}

sub parse_conditionals
{
    my $self = shift;
    my @conds = @_;
    my @results = ();
    my $cmp_name;
    my %parts;

    return '' unless @conds;
    my $ci = $self->current_indent();
    my $ciif = $ci . '    ';
    my $result = "${ci}if (\n$ciif";
    foreach my $condinfo (@conds)
    {
        my ($var, $op, $value) = @{$condinfo};
        #print STDERR "COND Looking at ($var, $op, $value)\n";
        $cmp_name = Idval::Select::get_compare_function_name($op, $value);
        push(@{$parts{$var}}, [$cmp_name, $op, $value]);
    }

    push(@results, "(\$ar_selects = ck_selects(\$selects, \\\%vars, [qw{" . join(' ', keys %parts) . '}]))');
    #print STDERR "COND: parts is ", Dumper(\%parts);
    foreach my $item (keys %parts)
    {
        # If there is more than one factor with the same name (i.e., GENRE == 22 and GENRE == 23)
        # they are ORed together
        if(scalar(@{$parts{$item}}) > 1)
        {
            my @oritems = ();
            foreach my $oritem (@{$parts{$item}})
            {
                my ($fname, $op, $value) = @{$oritem};
                #print STDERR "COND oritem: ($fname, $op, $value)\n";
                push(@oritems, "$fname(\$ar_selects->{$item}, q{$value})");
            }

            push(@results, '(' . join(" ||\n$ciif ", @oritems) . ')');
        }
        else
        {
            my ($fname, $op, $value) = @{${$parts{$item}}[0]};
            push(@results, "$fname(\$ar_selects->{$item}, q{$value})");
        }
    }

    $result .= join(" &&\n$ciif", @results) . "\n${ci}   )\n";
    return $result;
}

sub parse_conditionals_old
{
    my $self = shift;
    my @conds = @_;
    my @results = ();
    my $cmp_name;
    my %parts;

    return '' unless @conds;
    my $ci = $self->current_indent();
    my $ciif = $ci . '    ';
    my $result = "${ci}if (\n$ciif";
    foreach my $condinfo (@conds)
    {
        my ($var, $op, $value) = @{$condinfo};
        #print STDERR "COND Looking at ($var, $op, $value)\n";
        $cmp_name = Idval::Select::get_compare_function_name($op, $value);
        push(@{$parts{$var}}, [$cmp_name, $op, $value]);
    }

    #print STDERR "COND: parts is ", Dumper(\%parts);
    foreach my $item (keys %parts)
    {
        push(@results, "exists(\$selects->{$item})");
        # If there is more than one factor with the same name (i.e., GENRE == 22 and GENRE == 23)
        # they are ORed together
        if(scalar(@{$parts{$item}}) > 1)
        {
            my @oritems = ();
            foreach my $oritem (@{$parts{$item}})
            {
                my ($fname, $op, $value) = @{$oritem};
                #print STDERR "COND oritem: ($fname, $op, $value)\n";
                push(@oritems, "$fname(\$selects->{$item}, q{$value})");
            }

            push(@results, '(' . join(" or\n$ciif ", @oritems) . ')');
        }
        else
        {
            my ($fname, $op, $value) = @{${$parts{$item}}[0]};
            push(@results, "$fname(\$selects->{$item}, q{$value})");
        }
    }

    $result .= join(" and\n$ciif", @results) . "\n${ci}   )\n";
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

    #print STDERR "In parse_vars, got ", scalar(@vars), " vars\n";
    foreach my $varinfo (@vars)
    {
        my ($var, $op, $value) = @{$varinfo};
        $value =~ s/\%DATA\%/$self->{datadir}/gx;

        #print STDERR "Looking at ($var, $op, $value)\n";
        if ($op eq '=')
        {
            #print STDERR "Got \"=\" op\n";
            push(@results, '$vars{q{' . $var . '}} = q{' . $value . '};');
        }
        else                    # op is '+='
        {
            #print STDERR "Got \"$op\" op\n";
            #push(@results, '$vars{' . $var . '} = exists($vars{' . $var . '}) ? [$vars{' . $var . '}, q{' . $value . '}] : q{' . $value . '};');
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
    my $retval = $self->{INDENT} x $self->{LEVEL} . "}\n";

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
    $self->{LEVEL} = 1;
    $self->{INDENT} = '  ';

    my $subr = "sub\n{\n  my \$selects = shift;\n  my \%vars;\n  my \$ar_selects;\n\n";
    #$subr .= 'print STDERR "from SUBR: ", Dumper($selects);' . "\n";
    foreach my $line (split(/\n|\r\n|\r/, $cfg_text))
    {
        #print STDERR "Looking at: <$line>\n";
        #print STDERR "vars: ", Dumper(\@vars);
        $line =~ /^\s*{\s*$/ and do {
            $subr .= $self->parse_conditionals(@conditionals);
            my @var_results = $self->parse_vars(@vars);
            #print STDERR "Var results: ", Dumper(\@var_results);
            if (@var_results)
            {
                $subr .= $self->into();
                $subr .= $self->indent_lines(@var_results);
                $subr .= $self->out_of();
            }
            $subr .= $self->into();
            @conditionals = ();
            @vars = ();
            next;
        };

        $line =~ /^\s*}\s*$/ and do {
            #print STDERR "going into \"}\"\n";
            $subr .= $self->parse_conditionals(@conditionals);
            my @var_results = $self->parse_vars(@vars);
            print STDERR "Var results: ", Dumper(\@var_results);
            if (@var_results)
            {
                $subr .= $self->into();
                $subr .= $self->indent_lines(@var_results);
                $subr .= $self->out_of();
            }
            $subr .= $self->out_of();
            @conditionals = ();
            @vars = ();
            next;
        };

        $line =~ /^\s*(#.*)$/ and do {
            #$xml .= "<!-- $1 -->\n";
            next;
        };

        $line =~ m/^\s*$/ and do {
            next;
        };

        #$line =~ m{^\s*([%[:alnum:]][\w%-]*)($cmp_regex)(.*)\s*$}imx and do {
        $line =~ m{^\s*(\S+)\s*($cmp_regex)(.*)\s*$}imx and do {
            my $name = $1;
            my $op = $2;
            my $value = $3;
            $op =~ s/^\s+//;
            $op =~ s/\s+$//;
            push(@conditionals, [$name, $op, $value]);
            next;
        };

        #$line =~ m{^\s*([%[:alnum:]][\w%-]*)($assign_regex)(.*)\s*$}imx and do {
        $line =~ m{^\s*(\S+)\s*($assign_regex)(.*)\s*$}imx and do {
            my $name = $1;
            my $op = $2;
            my $value = $3;
            $op =~ s/^\s+//;
            $op =~ s/\s+$//;
            push(@vars, [$name, $op, $value]);
            next;
        };


        idv_warn("Unrecognized input line <$line>\n");
    }

    $subr .= 'print STDERR "from SUBR: ", Dumper(\%vars);' . "\n";
    $subr .= $self->current_indent() . 'return \%vars;' . "\n}\n";

    print STDERR "returning <\n$subr\n>";
    return $subr;
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

# For any node, there are three possible kinds of keys
#  'select', which contains the selection information
#  'group',  which is a list of child nodes
#  anything else, which indicate a key->value pair
#
#  For each node N in a list of nodes:
#    evaluate it (using the 'select' key, if present) to see if it should be processed or skipped
#    if it should be processed:
#       add key->value pairs to result
#       recurse into the nodes of N->{'group'}
#    else
#       next
#  end for
#

sub visit
{
    my $self = shift;
    my $node_list_ref = shift;
    my $name = shift;
    my $level = shift;
    my $subr = shift;

    my $status;

    #print "visit ($level): ref of node_list_ref is: ", ref $node_list_ref, "\n";
    #print("visit ($level): visiting \"$name\", with ", scalar(@{$node_list_ref}), " nodes\n");

    fatal("node_list_ref not an ARRAY ref") unless ref $node_list_ref eq 'ARRAY';
    foreach my $node (@{$node_list_ref})
    {
        # Should we process this node?
        $status = &$subr($self, $node);
        #print ("visit ($level): subr returned ", defined($status) ? "\"$status\"" : "undefined", "\n");
        return if $status == 2; # short-circuit finish
        if ($status)
        {
#             # Don't allow 'select' as a regular key
#             if (exists($node->{'group'}) && (ref($node->{'group'}) ne 'HASH'))
#             {
#                 fatal("Dis-allowed configuration name 'group' found");
#             }

            # Do we have any sub-nodes to visit?
            my $kids = [];
            if (exists($node->{'group'}))
            {
                if (ref($node->{'group'}) eq 'ARRAY')
                {
                    $kids = $node->{'group'};
                }
                elsif (ref($node->{'group'}) eq 'HASH')
                {
                    $kids = [$node->{'group'}];
                }

                if ($kids)
                {
                    my $nameid = sprintf "node%03d000", $level;
                    $level++;
                    $self->visit($kids, $nameid++, $level, $subr);
                }
                else
                {
                    #print "visit ($level): No kids for \"$name\"\n";
                }
            }
        }
    }
}

sub merge_blocks_old
{
    my $self = shift;
    my $selects = shift;
    my $tree = $self->{TREE};
    local %vars;
    my $match_status;
    my $match_id;

    #idv_dbg("Start of _merge_blocks, selects: ", Dumper($selects)); ##Dumper

    my $visitor = sub {
        my $self = shift;
        my $noderef = shift;

        #idv_dbg("merge_blocks: noderef is: ", Dumper($noderef)); ##Dumper
        return 0 if ($self->evaluate($noderef, $selects) == 0);

        idv_dbg("merge_blocks: evaluate returned nonzero\n"); ##debug1
        foreach my $key (sort keys %{$noderef})
        {
            idv_dbg("merge_blocks: checking key $key\n"); ##debug1
            next if ($key eq 'group');
            next if ($key eq 'select');

            my $value = $noderef->{$key};
            my $append = 0;
            idv_dbg("ref of value is: ", ref $value, "\n"); ##debug1
            if (ref $value eq 'HASH')
            {
                if (!exists($value->{append}))
                {
                    fatal("Unexpected attributes for value: ", join(', ', sort keys %{$value}));
                }
                $append = $value->{append};
                $value = $value->{content};
                $value =~ s/\%DATA\%/$self->{datadir}/gx;
            }
            elsif (ref $value eq 'ARRAY')
            {
                # XML::Simple has already done it for us
                my @newlist;
                my $newvalue;
                foreach my $item (@{$value})
                {
                    $newvalue = (ref $item eq 'HASH') ? $item->{content} : $item;
                    $newvalue =~ s/\%DATA\%/$self->{datadir}/gx;

                    push(@newlist, $newvalue);
                }
                $value = \@newlist;
            }
            else
            {
                $value =~ s/\%DATA\%/$self->{datadir}/gx;
            }

            idv_dbg("merge_blocks: Adding \"$value\" to \"$key\"\n"); ##debug1
            #print "value: ", Dumper($value);
            if ($append)
            {
                # If it's alread been appended, push
                # Otherwise, make it a list ref
                $vars{$key} = ref $vars{$key} ? push(@{$vars{$key}}, $value) : [$vars{$key}, $value];
            }
            else
            {
                $vars{$key} = $value;
            }
        }

        return 1;
    };

    $self->visit([$tree], 'top', 0, $visitor);

    #idv_dbg("Result of merge blocks - VARS: ", Dumper(\%vars)); ##Dumper

    return \%vars;
}

# For when we just want to know if some selector matched something
sub match_blocks
{
    my $self = shift;
    my $selects = shift;
    my $tree = $self->{TREE};
    my $match_status = 0;
    my $result;

    #idv_dbg("Start of match_blocks, selects: ", Dumper($selects)); ##Dumper

    my $visitor = sub {
        my $self = shift;
        my $noderef = shift;

        #idv_dbg("match_blocks: noderef is: ", Dumper($noderef)); ##Dumper
        my $eval_status = $self->evaluate($noderef, $selects);
        return 0 if $eval_status == 0;
        return 1 if $eval_status == 2;

        # Otherwise, we got it - no need to check _anything_ else
        $match_status = 1;
        return 2;
    };

    $self->visit([$tree], 'top', 0, $visitor);
    $result = $match_status;
    $match_status = 0;

    #idv_dbg("Result of match blocks is $result\n"); ##debug1

    return $result;
}

# See if the selector keys in $select_list match the selector keys in
# the block ($noderef).
# If the block doesn't have any selector keys, it always matches.
# again, $noderef is the block from the config file
#        $select_list are the selectors passed in to get_value (for instance, a tag record)

sub evaluate
{
    my $self = shift;
    my $noderef = shift;
    my $select_list = shift;
    my $retval = 1;
    my @s_key_list;
    my $match = '';
    my $is_regexp = 0;

    #idv_dbg("in evaluate: ", Dumper($noderef)); ##Dumper
    #idv_dbg("evaluate: 1 select_list: ", Dumper($select_list)); ##Dumper
    # If the block has no selector keys itself, then all matches should succeed
    if (not (exists($noderef->{'select'})))
    {
        idv_dbg("Block has no selector keys, returning 2\n"); ##debug1
        return 2;
    }

    # Add the variables that have been defined (so far) to the selector list.
    # This lets us use variables defined previously in the configuration file
    # in block selections.
    # See ConfigTest.t:previously_defined_variable_can_be_used_as_selector()

    my %selectors = (%{$select_list}, %vars);

    #return 0 unless %selectors;

#       block_selector will look like this:
#       {
#           'value' => 'MP3',
#           'name' => [
#               'TYPE'
#               ],
#           'op' => '=='
#       }

  KEY_MATCH: foreach my $block_selector (@{$noderef->{'select'}})
    {
        my $block_key    = ${$block_selector->{name}}[0];
        my $block_op     = $block_selector->{op};
        my $block_value  = $block_selector->{value};

        # Certain variable names are interpreted as subroutines, and the
        # result of the subroutine is used as the value of the variable.
        if (exists ($self->{DEF_VARS}->{$block_key}))
        {
            #chatty("Using \"$block_key\" as subroutine name\n"); ##debug1
            no strict 'refs';
            my $subr = $self->{DEF_VARS}->{$block_key};
            $selectors{$block_key} = &$subr(\%selectors);
            #chatty ("Using ", $selectors{$block_key}, " for \"$block_key\"\n"); ##debug1
            use strict;
        }

        my $block_cmp_func = Idval::Select::get_compare_function($block_op, $block_value);

#   KEY_MATCH: foreach my $block_key (keys %{$noderef->{'select'}})
#     {
#         # Certain variable names are interpreted as subroutines, and the
#         # result of the subroutine is used as the value of the variable.
#         if (exists ($self->{DEF_VARS}->{$block_key}))
#         {
#             chatty("Using \"$block_key\" as subroutine name\n");
#             no strict 'refs';
#             my $subr = $self->{DEF_VARS}->{$block_key};
#             $selectors{$block_key} = &$subr(\%selectors);
#             chatty ("Using ", $selectors{$block_key}, " for \"$block_key\"\n");
#             use strict;
#         }

#         my $bstor = $noderef->{'select'}->{$block_key}; # Naming convenience
#         my $block_op = $bstor->{'op'};
#         my $block_value = $bstor->{'value'};
#         my $block_cmp_func = Idval::Select::get_compare_function($block_op, $block_value);

        # A couple of special-case operators that need to be able to
        # look at (possibly non-existing) selector keys.
        if ($block_op eq 'passes' or $block_op eq 'fails')
        {
            #idv_dbg("Comparing \"selector list\" \"$block_key\" \"$block_op\" \"$block_value\" resulted in ",
            #      &$block_cmp_func(\%selectors, $block_key, $block_value) ? "True\n" : "False\n");

            my $cmp_result = &$block_cmp_func(\%selectors, $block_key, $block_value);

            $retval &&= $cmp_result;
            next KEY_MATCH;
        }

        #idv_dbg("evaluate: 2 select_list: ", Dumper(\%selectors)); ##Dumper
        #idv_dbg("Checking block selector \"$block_key\"\n"); ##debug1

#        @s_key_list = ($block_key);
        @s_key_list = $self->{ALLOW_KEY_REGEXPS} ? grep(/^$block_key$/, keys %selectors) :
            ($block_key);

# XXX Throw out ALLOW_KEY_REGEXPS changes. That's just dumb. We do need to keep track of _all_
# the tags that matched (only in blocks that have a GRIPE variable...)

        $is_regexp = $block_key =~ m/\W/;
        foreach my $s_key (@s_key_list)
        {
            if (!exists($selectors{$s_key}))
            {
                # The select list has nothing to match a required selector, so this must fail
                return 0;
            }


            # Make sure arg_value is a list reference
            my $arg_value_list = ref $selectors{$s_key} eq 'ARRAY' ? $selectors{$s_key} :
                [$selectors{$s_key}];

            my $cmp_result = 0;

            # For any key, the passed_in selector may have a list of values that it can offer up to be matched.
            # A successful match for any of these values constitutes a successful match for the block selector.
            foreach my $value (@{$arg_value_list})
            {
                #idv_dbg("Comparing \"$value\" \"$block_op\" \"$block_value\" resulted in ",
                #      &$block_cmp_func($value, $block_value) ? "True\n" : "False\n");

                $cmp_result ||= &$block_cmp_func($value, $block_value);
                last if $cmp_result;
            }

            if ($is_regexp)
            {
                $retval ||= $cmp_result;
            }
            else
            {
                $retval &&= $cmp_result;
            }

            if (!$retval)
            {
                #print "Config: match id is \"$s_key\"\n";
                last KEY_MATCH;
            }
        }
    }

    #print("evaluate returning $retval\n");
    return $retval;
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
    idv_dbg("In get_single_value with key \"$key\"\n"); ##debug1
    my $vars = $self->merge_blocks($selects);
    #idv_dbg("get_single_value: list result for \"$key\" is: ", Dumper($vars->{$key})); ##Dumper
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

    return $self->match_blocks($selects);
}

# package Idval::Config::Methods;

# use strict;
# use Config;

# use Idval::Logger qw(fatal);
# use Idval::FileIO;

# sub get_system_type
# {
#     return $Config{osname};
# }

# sub get_mtime
# {
#     my $selectors = shift;

#     fatal("No filename in selectors") unless exists $selectors->{FILE};
#     return Idval::FileIO::idv_get_mtime($selectors->{FILE});
# }

# sub get_file_age
# {
#     my $selectors = shift;
#     return time - Idval::FileIO::idv_get_mtime($selectors->{FILE});
# }

1;
