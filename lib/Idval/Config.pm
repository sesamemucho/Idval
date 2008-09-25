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
use Carp qw(cluck croak confess);
use Memoize;
use File::Temp;

use Idval::Common;
use Idval::Constants;
use Idval::Select;
use Idval::FileIO;

my $xml_req_status = eval {require XML::Simple};
my $xml_req_msg = !defined($xml_req_status) ? "$!" :
    $xml_req_status == 0 ? "$@" :
    "Load OK";

if ($xml_req_msg ne 'Load OK')
{
    print "Oops; let's try again for XML::Simple\n";
    use lib Idval::Common::get_top_dir('lib/perl');

    $xml_req_status = eval {require XML::Simple};
    $xml_req_msg = 'Load OK' if (defined($xml_req_status) && ($xml_req_status != 0));
}

croak "Need XML support (via XML::Simple)" unless $xml_req_msg eq 'Load OK';

use constant STRICT_MATCH => 0;
use constant LOOSE_MATCH  => 1;

our $DEBUG = 0;
#our $DEBUG = 1;
our $USE_LOGGER = 1;
#our $USE_LOGGER = 0;

if (! $USE_LOGGER)
{
    *verbose = sub{ print @_; };
    *chatty = sub{ print @_; };
}
#*harfo  = Idval::Common::make_custom_logger({level => $CHATTY,
#                                              debugmask => $DBG_CONFIG,
#                                              decorate => 1}) unless defined(*harfo{CODE});

# # Make a flat list out of the arguments, which may be scalars or array refs
# # Leave out any undefined args.
# sub make_flat_list
# {
#     my @result = map {ref $_ eq 'ARRAY' ? @{$_} : $_ } grep {defined($_)} @_;
#     #harfo ("make_flat list: result is: ", Dumper(\@result));
#     return \@result;
# }

##sub normalize { join ' ', $_[0], $_[1], map{ @{$_} } @{$_[2]}}
###memoize('_merge_blocks', NORMALIZER => 'normalize');
#memoize('_merge_blocks');
#our %memohash;
# memoize('_merge_blocks', INSTALL => 'fast_merge_blocks',
#         SCALAR_CACHE => [HASH => \%memohash]);

# memoize('_merge_blocks', INSTALL => 'fast_merge_blocks_1',
#         NORMALIZER => 'normalize',
#         SCALAR_CACHE => [HASH => \%memohash]);

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
    #my $unmatched_selector_keys_ok = shift;
    my $init_debug = shift || 0;

    #$unmatched_selector_keys_ok = STRICT_MATCH unless defined($unmatched_selector_keys_ok);
    #$unmatched_selector_keys_ok = 0;
    if ($USE_LOGGER)
    {
        *verbose = Idval::Common::make_custom_logger({level => $VERBOSE,
                                                      debugmask => $DBG_CONFIG,
                                                      from => 'BARFO',
                                                      decorate => 1}) unless defined(*verbose{CODE});

        *chatty  = Idval::Common::make_custom_logger({level => $CHATTY,
                                                      debugmask => $DBG_CONFIG,
                                                      decorate => 1}) unless defined(*chatty{CODE});
    }

    $self->{INITFILES} = [];
#    $self->{TREE} = {};
    $self->{DEBUG} = $init_debug;
#    $self->{USK_OK} = $unmatched_selector_keys_ok;
    $self->{datadir} = Idval::Common::get_top_dir('Data');
    $self->{HAS_YAML_SUPPORT} = 0;

    if ($initfile)
    {
        $self->add_file($initfile);
    }

    $self->{DEF_VARS} = $self->merge_blocks({config_group => 'idval_calculated_variables'});

    return;
}

sub debug
{
    my $self = shift;
    my $debug = shift;

    $self->{DEBUG} = $debug if defined($debug);

    return $self->{DEBUG};
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
    croak "Need a file" unless @{$self->{INITFILES}}; # We do need at least one config file


    my $xmltext = "<config>\n";
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


            $fh = Idval::FileIO->new($fname, "r") || do {print STDERR Carp::shortmess("shormess");
                                                     croak "Can't open \"$fname\" for reading: $! in " . __PACKAGE__ . " line(" . __LINE__ . ")";};
        }

        $text = do { local $/ = undef; <$fh> };
        $fh->close();

        if ($fname =~ m/tmp/)
        {
            #print "For \"$fname\", text is: \"$text\"\n";
        }

        if ($fname =~ m/\.xml$/i)
        {
            $text =~ s|\A.*?<config>||i;
            $text =~ s|</config>.*?\z||i;
            $xmltext .= $text;
        }
        elsif ($fname =~ m/\.yml$/i)
        {
            if ($self->{HAS_YAML_SUPPORT})
            {
                my $c = YAML::Tiny->read_string($text);
                my $hr = $$c[1];
                my $data = XMLout($hr);
                $data =~ s|\A.*?<opt>||i;
                $data =~ s|</opt>.*?\z||i;
                $xmltext .= $data;
            }
            else
            {
                croak "This installation of idv does not have YAML support.";
            }
        }
        else # Must be a idv-style config file
        {
            $xmltext .= $self->config_to_xml($text);
        }
    }

    $xmltext .= "</config>\n";
    eval { $self->{TREE} = XML::Simple::XMLin($xmltext, keyattr => {select=>'name'}, forcearray => ['select']); };
    if ($@)
    {
        print "Error from XML conversion: $@\n";
        my ($linenum, $col, $byte) = ($@ =~ m/ line (\d+), column (\d+), byte (\d+)/);
        $linenum = 0 unless (defined($linenum) && $linenum);
        my $i = 1;
        foreach my $line (split("\n", $xmltext))
        {
            printf "%3d: %s\n", $i, $line;
            if ($i == $linenum)
            {
                print '.....' . '.' x ($col - 1) . "^\n";
            }

            $i++;
        }
        print "\n\n";
        croak;
    }

    $self->{XMLTEXT} = $xmltext; # In case someone wants to see it later
    $self->{PRETTY} = XML::Simple::XMLout($self->{TREE},
                                          NoAttr => 1,
                                          KeepRoot => 1,
        );

    if($self->{DEBUG})
    {
        print "xmltext: ", $self->{XMLTEXT};
        print "\n\n\n";
        print "XML: ", $self->{PRETTY};
        print "\n\n\n";
        print "TREE: ", Dumper($self->{TREE});
    }
    return;
}

sub config_to_xml
{
    my $self = shift;
    my $cfg_text = shift;
    my $xml = '';
    my $cmp_regex = Idval::Select::get_cmp_regex();
    my $assign_regex = Idval::Select::get_assign_regex();

    foreach my $line (split(/\n|\r\n|\r/, $cfg_text))
    {
        #print "Looking at: <$line>\n";

        $line =~ /^\s*{\s*$/ and do {
            $xml .= "<group>\n";
            next;
        };

        $line =~ /^\s*}\s*$/ and do {
            $xml .= "</group>\n";
            next;
        };

        $line =~ /^\s*(#.*)$/ and do {
            $xml .= "<!-- $1 -->\n";
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
            $op =~ s/>/\&gt;/;
            $op =~ s/</\&lt;/;
            $xml .= "<select name=\"$name\" op=\"$op\" value=\"$value\"/>\n";
            next;
        };

        #$line =~ m{^\s*([%[:alnum:]][\w%-]*)($assign_regex)(.*)\s*$}imx and do {
        $line =~ m{^\s*(\S+)\s*($assign_regex)(.*)\s*$}imx and do {
            my $name = $1;
            my $op = $2;
            $op =~ s/>/\&gt;/;
            $op =~ s/</\&lt;/;
            my $value = $3;
            if ($op =~ m/\+\=/)
            {
                $xml .= "<$name append=\"1\">$value</$name>\n";
            }
            else
            {
                $xml .= "<$name>$value</$name>\n";
            }
            next;
        };


        print "Unrecognized input line <$line>\n";
    }

    return $xml;
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

    confess "node_list_ref not an ARRAY ref" unless ref $node_list_ref eq 'ARRAY';
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
#                 croak "Dis-allowed configuration name 'group' found";
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

sub merge_blocks
{
    my $self = shift;
    my $selects = shift;
    my $tree = $self->{TREE};
    my %vars;
    my $match_status;
    my $match_id;

    print("Start of _merge_blocks, selects: ", Dumper($selects)) if $self->{DEBUG};

    my $visitor = sub {
        my $self = shift;
        my $noderef = shift;

        print "merge_blocks: noderef is: ", Dumper($noderef) if $self->{DEBUG};
        return 0 if ($self->evaluate($noderef, $selects) == 0);

        print "merge_blocks: evaluate returned nonzero\n" if $self->{DEBUG};
        foreach my $key (sort keys %{$noderef})
        {
            print "merge_blocks: checking key $key\n" if $self->{DEBUG};
            next if ($key eq 'group');
            next if ($key eq 'select');

            my $value = $noderef->{$key};
            my $append = 0;
            print "ref of value is: ", ref $value, "\n" if $self->{DEBUG};
            if (ref $value eq 'HASH')
            {
                if (!exists($value->{append}))
                {
                    croak "Unexpected attributes for value: ", join(', ', sort keys %{$value});
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

            #print "merge_blocks: Adding \"$value\" to \"$key\"\n";
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

    print("Result of merge blocks - VARS: ", Dumper(\%vars)) if $self->{DEBUG};

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

    print("Start of match_blocks, selects: ", Dumper($selects)) if $self->{DEBUG};

    my $visitor = sub {
        my $self = shift;
        my $noderef = shift;

        print "match_blocks: noderef is: ", Dumper($noderef) if $self->{DEBUG};
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

    print("Result of match blocks is $result\n") if $self->{DEBUG};

    return $result;
}

# See if the selector keys in $select_list match the selector keys in
# the block ($noderef).
# If the block doesn't have any selector keys, it always matches.

sub evaluate
{
    my $self = shift;
    my $noderef = shift;
    my $select_list = shift;
    my $retval = 1;
    my @s_key_list;
    my $match = '';
    my $is_regexp = 0;

    print "in evaluate: ", Dumper($noderef) if $DEBUG;
    print "evaluate: 1 select_list: ", Dumper($select_list) if $DEBUG;
    # If the block has no selector keys itself, then all matches should succeed
    if (not (exists($noderef->{'select'}) && ref($noderef->{'select'}) eq 'HASH'))
    {
        print "Block has no selector keys, returning 2\n" if $DEBUG;
        return 2;
    }

    my %selectors = %{$select_list};

    #return 0 unless %selectors;

  KEY_MATCH: foreach my $block_key (keys %{$noderef->{'select'}})
    {
        if (exists ($self->{DEF_VARS}->{$block_key}))
        {
            no strict 'refs';
            my $subr = $self->{DEF_VARS}->{$block_key};
            $selectors{$block_key} = &$subr(\%selectors);
            chatty ("Using ", $selectors{$block_key}, " for \"$block_key\"\n");
            use strict;
        }

        if ($block_key eq '%FILE_TIME%')
        {
            $selectors{$block_key} = Idval::FileIO::idv_get_mtime($selectors{FILE});
        }

        my $bstor = $noderef->{'select'}->{$block_key}; # Naming convenience
        my $block_op = $bstor->{'op'};
        my $block_value = $bstor->{'value'};
        my $block_cmp_func = Idval::Select::get_compare_function($block_op, $block_value);

        # A couple of special-case operators that need to be able to
        # look at (possibly non-existing) selector keys.
        if ($block_op eq 'passes' or $block_op eq 'fails')
        {
            print("Comparing \"selector list\" \"$block_key\" \"$block_op\" \"$block_value\" resulted in ",
                  &$block_cmp_func(\%selectors, $block_key, $block_value) ? "True\n" : "False\n") if $DEBUG;

            if (&$block_cmp_func(\%selectors, $block_key, $block_value))
            {
                return 1;
            }

            next KEY_MATCH;
        }

        print "evaluate: 2 select_list: ", Dumper(\%selectors) if $DEBUG;
        print("Checking block selector \"$block_key\"\n") if $DEBUG;

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
                print("Comparing \"$value\" \"$block_op\" \"$block_value\" resulted in ",
                      &$block_cmp_func($value, $block_value) ? "True\n" : "False\n") if $DEBUG;

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
    chatty ("In get_single_value with key \"$key\"\n") if $self->{DEBUG};
    my $vars = $self->merge_blocks($selects);
    chatty ("get_single_value: list result for \"$key\" is: ", Dumper($vars->{$key})) if $self->{DEBUG};
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

package Idval::Config::Methods;

use strict;
use Carp qw(cluck croak confess);
use Config;

use Idval::FileIO;

sub get_system_type
{
    return $Config{osname};
}

sub get_mtime
{
    my $selectors = shift;

    croak "No filename in selectors" unless exists $selectors->{FILE};
    return Idval::FileIO::idv_get_mtime($selectors->{FILE});
}

sub get_file_age
{
    my $selectors = shift;

    return time - Idval::FileIO::idv_get_mtime($selectors->{FILE});
}

1;
