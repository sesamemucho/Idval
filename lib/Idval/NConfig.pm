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
use Carp qw(cluck croak confess);
use Memoize;
#use Text::Balanced qw (
#                       extract_delimited
#                       extract_multiple
#                      );

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

if ($USE_LOGGER)
{
    *verbose = Idval::Common::make_custom_logger({level => $VERBOSE,
                                                  debugmask => $DBG_CONFIG,
                                                  decorate => 1}) unless defined(*verbose{CODE});
    *chatty  = Idval::Common::make_custom_logger({level => $CHATTY,
                                                  debugmask => $DBG_CONFIG,
                                                  decorate => 1}) unless defined(*chatty{CODE});
}
else
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
#     *verbose = Idval::Common::make_custom_logger({level => $VERBOSE,
#                                                   debugmask => $DBG_CONFIG,
#                                                   decorate => 1}) unless defined(*verbose{CODE});
#     *chatty  = Idval::Common::make_custom_logger({level => $CHATTY,
#                                                   debugmask => $DBG_CONFIG,
#                                                   decorate => 1}) unless defined(*chatty{CODE});

#      *chatty  = Idval::Common::make_custom_logger({level => $CHATTY,
#                                                    debugmask => $DBG_CONFIG,
#                                                    decorate => 1,
#                                                  from=>'CHATTY'}) unless defined(*chatty{CODE});

#    $self->{OP_REGEX} = Idval::Select::get_op_regex();
#    $self->{ASSIGN_OP_REGEX} = Idval::Select::get_assign_regex();
#    $self->{CMP_OP_REGEX} = Idval::Select::get_cmp_regex();
    $self->{INITFILES} = [];
#    $self->{TREE} = {};
    $self->{DEBUG} = $init_debug;
#    $self->{USK_OK} = $unmatched_selector_keys_ok;

    $self->{HAS_YAML_SUPPORT} = 0;

    if ($initfile)
    {
        $self->add_file($initfile);
    }

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

    #print "Adding file \"$initfile\"\n";
    return unless $initfile;      # Blank input file names are OK... Just don't do anything.
    push(@{$self->{INITFILES}}, $initfile);
    croak "Need a file" unless @{$self->{INITFILES}}; # We do need at least one config file


    my $xmltext = "<config>\n";
    my $text = '';
    my $fh;

    foreach my $fname (@{$self->{INITFILES}})
    {
            
        $fh = Idval::FileIO->new($fname, "r") || do {print STDERR Carp::shortmess("shormess");
                                                     croak "Can't open \"$fname\" for reading: $! in " . __PACKAGE__ . " line(" . __LINE__ . ")";};
        $text = do { local $/ = undef; <$fh> };
        $fh->close();

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
        print "xml text is:\n";
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

#     #nope $text =~ s/^\s*#.*$//mgx;      # Remove comments
#     $text =~ s/^\n+//sx;         # Trim off newline(s) at start
#     $text =~ s/\n+$//sx;         # Trim off newline(s) at end


#     $self->{NODENAME} = 'Node0000';
#     my $top = $self->parse_blocks("\{$text\}");
#     $self->{TREE} = $top->{NODE}->{'Node0000'};

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

        $line =~ m{^\s*([[:alnum:]][\w-]*)($cmp_regex)(.*)\s*$}imx and do {
            my $name = $1;
            my $op = $2;
            my $value = $3;
            $op =~ s/^\s+//;
            $op =~ s/\s+$//;
            $xml .= "<select name=\"$name\" op=\"$op\" value=\"$value\"/>\n";
            next;
        };
        
        $line =~ m{^\s*([[:alnum:]][\w-]*)($assign_regex)(.*)\s*$}imx and do {
            $xml .= "<$1>$3</$1>\n";
            next;
        };
        

        print "Unrecognized input line <$line>\n";
    }

    return $xml;
}

sub visit
{
    my $noderef = shift;
    my $name = shift;
    my $level = shift;
    my $subr = shift;

    #confess "top is undefined?" unless defined $top;
    #print("visiting \"$name\"\n");
    #print "ref of \"$name\": ", ref $noderef, "\n";
    #print "keys of \"$name\": ", join(', ', keys %{$noderef}), "\n";
    #print "ref of group: ", ref($noderef->{'group'}), "\n";
    #print "dump of group: ", Dumper($noderef->{'group'});
    #print "group: " , join(", ", @{$noderef->{'group'}}), "\n";
    my $retval = &$subr($noderef);

    # If retval is undef, this node is not for us
    # and therefore, none of its children are, either
    #chatty("return from subr on ", $top->myname(), " is undef\n") if not defined($retval);
    #return if not defined($retval);

    # get_children returns a list of child nodes, sorted
    # by nodename.
    # The children of this node are the items in the list keyed by 'group' (if it exists)
    # Allow the existence of a plain tag named 'group'.
    my @kids = ();
    if (exists($noderef->{'group'}) && ref($noderef->{'group'}) eq 'ARRAY')
    {
        @kids = @{$noderef->{'group'}};
    }

    print "kids of \"$name\": ", join(", ", @kids), "\n";
    my $nameid = sprintf "node%03d000", $level;
    $level++;
    foreach my $child (@kids)
    {
        visit($child, $nameid++, $level, $subr);
    }

    return;
}

sub merge_blocks
{
    my $self = shift;
    my $selects = shift;
    my $tree = $self->{TREE};
    my %vars;

    print("Start of _merge_blocks, selects: ", Dumper($selects));

    my $visitor = sub {
        my $noderef = shift;

        return if evaluate($noderef, $selects) == 0;

        #print "evaluate returned nonzero\n";
        #print "merge_blocks: noderef is: ", Dumper($noderef);
        #return 1 if not exists $noderef->{'set'};
        #my $set_list_ref = ref $noderef->{'set'} eq 'HASH' ? [$noderef->{'set'}] :
        #    $noderef->{'set'};
        #foreach my $val_href (@{$set_list_ref})
        foreach my $key (sort keys %{$noderef})
        {
            #my $name = $val_href->{'name'};
            #my $value = $val_href->{'value'};
            #print "Adding \"$value\" to \"$name\"\n";
            #$vars{$name} = $value;
            my $value = $noderef->{$key};
            next if ref $value;
            print "Adding \"$value\" to \"$key\"\n";
            $vars{$key} = $value;
        }

        return 1;
    };

    visit($tree, 'top', 0, $visitor);

    print("Result of merge blocks - VARS: ", Dumper(\%vars));

    return \%vars;
}

sub evaluate
{
    my $noderef = shift;
    my $select_list = shift;
    my $retval = 1;

    print "in evaluate: ", Dumper($noderef);
    print "select_list: ", Dumper($select_list);
    # If the block has no selector keys itself, then all matches should succeed
    return 1 unless (exists($noderef->{'select'}) && ref($noderef->{'select'}) eq 'HASH');
#my $stor = $noderef->{'select'}->{$selector};
#print "select $selector op $stor->{'op'} against $stor->{'value'}\n";
#Got selector(s)
#select DATE op == against YEAR
#select type op == against FLAC

    my %selectors = %{$select_list};

    return 0 unless %selectors;

    foreach my $block_key (keys %{$noderef->{'select'}})
    {
        print("Checking block selector \"$block_key\"\n");
        if (!exists($select_list->{$block_key}))
        {
            # The select list has nothing to match a required selector, so this must fail
            return 0;
        }
        my $bstor = $noderef->{'select'}->{$block_key};

        my $arg_value_list = ref $selectors{$block_key} eq 'ARRAY' ? $selectors{$block_key} : [$selectors{$block_key}];
        # Now, arg_value is guaranteed to be a list reference

        my $block_op = $bstor->{'op'};
        my $block_value = $bstor->{'value'};
        my $block_cmp_func = Idval::Select::get_compare_function($block_op, 'STR');
        my $cmp_result = 0;

        # For any key, the passed_in selector may have a list of values that it can offer up to be matched.
        # A successful match for any of these values constitutes a successful match for the block selector.
        foreach my $value (@{$arg_value_list})
        {
            print("Comparing \"$value\" \"$block_op\" \"$block_value\" resulted in ",
                  &$block_cmp_func($value, $block_value) ? "True\n" : "False\n");

            $cmp_result ||= &$block_cmp_func($value, $block_value);
            last if $cmp_result;
        }

        $retval &&= $cmp_result;
        last if !$retval;
    }

    print("evaluate returning $retval\n");
    return $retval;
}

# sub check_it_out
# {
#     my $noderef = shift;

#     if(exists($noderef->{'select'}))
#     {
#         print "Got selector(s)\n";
#         foreach my $selector (keys %{$noderef->{'select'}})
#         {
#             my $stor = $noderef->{'select'}->{$selector};
#             print "select $selector op $stor->{'op'} against $stor->{'value'}\n";
#         }
#         print "\n";
#     }

#     foreach my $key (sort keys %{$noderef})
#     {
#         next if ref $noderef->{$key};

#         print "Got assignment: $key = $noderef->{$key}\n";
#     }

#     return;
# }

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























# sub get_next_nodename
# {
#     my $self = shift;
#     my $newnode = $self->{NODENAME}++;
#     chatty ("returning nodename $newnode\n") if $self->{DEBUG};
#     return $newnode;
# }

# sub extract_blocks
# {
#     my $self = shift;
#     my $text = shift;

#     my @blocks;
#     my ($extracted, $remainder, $skipped);
#     my $front = '';

#     chatty ("in extract_blocks\n") if $self->{DEBUG};
#     while(1)
#     {
#         ($extracted, $remainder, $skipped) = Text::Balanced::extract_codeblock($text, '{}', '[^{}]*');
#         chatty ("extracted: \"$extracted\", remainder is: \"$remainder\", skipped: \"$skipped\"\n") if $self->{DEBUG};

#         last unless $extracted;

#         push(@blocks, $extracted);

#         $text = $remainder;
#         $front .= $skipped;
#     }

#     $remainder = $front . $remainder;
#     chatty ("** blocks are: ", join('::', @blocks), "   remainder is: \"$remainder\"\n") if $self->{DEBUG};
#     return (\@blocks, $remainder);
# }

# sub parse_one_block
# {
#     my $self = shift;
#     my $node = shift;
#     my $text = shift;

#     my $op_regex = $self->{OP_REGEX};

#     my $current_tag = undef;
#     my $current_op;
#     my $current_value;

#     return unless defined $text; # Nothing to do...

#     chatty ("parse_one_block, op_regex is: \"$op_regex\"\ndata is: <$text>\n") if $self->{DEBUG};

#     foreach my $line (split(/\n/x, $text))
#     {
#         chomp $line;
#         $line =~ s{\r}{}gx;
#         $line =~ s/\#.*$//x;      # Remove comments
#         next if $line =~ m/^\s*$/x;

#         if ($line =~ m{^([[:alnum:]][\w-]*)($op_regex)(.*)$}imx)
#         {
#             $node->add_data($current_tag, $current_op, $current_value) if defined $current_tag;
#             chatty ("Got tag of \"$1\" \"$2\" \"$3\" \n") if $self->{DEBUG};
#             $current_tag = $1;
#             $current_op = $2;
#             $current_value = $3;

#             $current_op =~ s/\s//gx;
#             next;
#         };

#         if ($line =~ m{^\s+(.*)$}imx)
#         {
#             croak("Found unexpected continuation line \"$line\" at the beginning of a block") unless defined $current_tag;
#             chatty ("Got continuation tag of \"$1\" \"$2\" \"$3\" \n") if $self->{DEBUG};
#             $current_value .= $3;
#             next;
#         };

#         cluck("Unrecognized configuration entry \"$line\"\n");
#     }

#     $node->add_data($current_tag, $current_op, $current_value) if defined $current_tag;

#     return;
# }

# sub parse_blocks
# {
#     my $self = shift;
#     my $text = shift;

#     my $tree = Idval::NConfig::Block->new($self->{DEBUG}, $self->{USK_OK});
#     my ($kidsref, $data) = $self->extract_blocks($text);
#     my $child_name;
#     my $op_regex = $self->{OP_REGEX};

#     # Clean it up
#     $data =~ s/^\s+//gmx;
#     $data =~ s/\s+$//gmx;

#     # Preprocess the data, for use in the visit subroutine
#     $self->parse_one_block($tree, $data);

#     chatty ("Current node has ", scalar(@{$kidsref}), " children.\n") if $self->{DEBUG};
#     foreach my $blk (@{$kidsref})
#     {
#         chop $blk;
#         $blk = substr($blk, 1);
#         $child_name = $self->get_next_nodename();
#         chatty ("At \"$child_name\", Looking at: \"$blk\"\n") if $self->{DEBUG};
#         $tree->add_node($child_name, $self->parse_blocks($blk));
#     }

#     chatty ("tree: ", Dumper($tree)) if $self->{DEBUG};
#     return $tree;
# }

# sub visit
# {
#     my $self = shift;
#     my $top = shift;
#     my $subr = shift;

#     confess "top is undefined?" unless defined $top;
#     #chatty("visiting ", $top->myname(), "\n");
#     my $retval = &$subr($top);

#     # If retval is undef, this node is not for us
#     # and therefore, none of its children are, either
#     chatty("return from subr on ", $top->myname(), " is undef\n") if not defined($retval);
#     return if not defined($retval);

#     # get_children returns a list of child nodes, sorted
#     # by nodename.
#     foreach my $node (@{$top->get_children()})
#     {
#         $self->visit($node, $subr);
#     }

#     return;
# }

# sub merge_blocks
# {
#     my $self = shift;
#     my $selects = shift;
#     my %vars;

#     confess "selects argument required for config call" unless (defined($selects) && $selects);
#     verbose ("Start of _merge_blocks, selects: ", Dumper($selects)) if $self->{DEBUG};

#     if ($Idval::NConfig::DEBUG)
#     {
#         print STDERR "Start of _merge_blocks, selects: ", Dumper($selects);
#     }

#     # visit each node, in correct order
#     # if node evaluates to TRUE,
#     #    accumulate values (including appends)

#     # When finished with tree, return hash of values

#     my $visitor = sub {
#         my $node = shift;
#         # can't take this shortcut any more
#         # But we could maybe if evaluate returned
#         # 0 => no matches on any select
#         # 1 => a match on at least one select (allows descent)
#         # 2 => matches on all selects
#         print "node: ", Dumper($node);
#         confess "huh";
#         return if $node->evaluate($selects) == 0;

#         foreach my $name (@{$node->get_assignment_data_names()})
#         {
#             my ($op, $value) = $node->get_assignment_data_values($name);
#             chatty ("name \"$name\" op \"$op\" value \"$value\"\n") if $self->{DEBUG};

#             if ($op eq '=')
#             {
#                 chatty ("For \"$name\", op is \"=\" and value is \"$value\"\n") if $self->{DEBUG};
#                 $vars{$name} = $value;
#             }
#             elsif ($op eq '+=')
#             {
#                 chatty ("For \"$name\", op is \"+=\" and value is \"$value\"\n") if $self->{DEBUG};
#                 $vars{$name} = make_flat_list($vars{$name}, $value);
#             }
#         }

#         return 1;
#     };

#     $self->visit($self->{TREE}, $visitor);

#     chatty ("Result of merge blocks - VARS: ", Dumper(\%vars)) if $self->{DEBUG};

#     return \%vars;
# }

# sub get_single_value
# {
#     my $self = shift;
#     my $key = shift;
#     my $selects = shift;
#     my $default = shift || '';

#     my $value = $self->get_value($key, $selects, $default);

#     return ref $value eq 'ARRAY' ? ${$value}[0] : $value;
# }

# sub get_list_value
# {
#     my $self = shift;
#     my $key = shift;
#     my $selects = shift;
#     my $default = shift || '';

#     my $value = $self->get_value($key, $selects, $default);

#     return ref $value eq 'ARRAY' ? $value : [$value];
# }

# sub get_value
# {
#     my $self = shift;
#     my $key = shift;
#     my $selects = shift;
#     my $default = shift || '';

#     #$cfg_dbg = ($key eq 'sync_dest');
#     chatty ("In get_single_value with key \"$key\"\n") if $self->{DEBUG};
#     my $vars = $self->merge_blocks($selects);
#     chatty ("get_single_value: list result for \"$key\" is: ", Dumper($vars->{$key})) if $self->{DEBUG};
#     return defined $vars->{$key} ? $vars->{$key} : $default;
# }

# sub value_exists
# {
#     my $self = shift;
#     my $key = shift;
#     my $selects = shift;

#     my $vars = $self->merge_blocks($selects);
#     return defined($vars->{$key});
# }

# package Idval::NConfig::Block;

# use strict;
# use warnings;
# use Data::Dumper;
# use English '-no_match_vars';
# use Carp;

# use Idval::Common;
# use Idval::Constants;

# if ($USE_LOGGER)
# {
#     *verbose = Idval::Common::make_custom_logger({level => $VERBOSE,
#                                                   debugmask => $DBG_CONFIG,
#                                                   decorate => 1}) unless defined(*verbose{CODE});
#     *chatty  = Idval::Common::make_custom_logger({level => $CHATTY,
#                                                   debugmask => $DBG_CONFIG,
#                                                   decorate => 1}) unless defined(*chatty{CODE});
# }
# else
# {
#     *verbose = sub{ print @_; };
#     *chatty = sub{ print @_; };
# }

# sub new
# {
#     my $class = shift;
#     my $self = {};
#     bless($self, ref($class) || $class);
#     $self->_init(@_);
#     return $self;
# }

# sub _init
# {
#     my $self = shift;
#     my $debug = shift;
#     my $unmatched_selector_keys_ok = shift;

#     $self->{ASSIGN_OP_REGEX} = Idval::Select::get_assign_regex();
#     $self->{datadir} = Idval::Common::get_top_dir('data');
#     $self->{libdir} = Idval::Common::get_top_dir('lib');

#     $self->{USK_OK} = $unmatched_selector_keys_ok;
#     $self->{DEBUG} = $debug;

#     return;
# }

# sub add_data
# {
#     my $self = shift;
#     my $name = shift;
#     my $op = shift;
#     my $value = shift;

#     confess "undef op" unless defined $op;

#     $value =~ s/\%DATA\%/$self->{datadir}/gx;
#     $value =~ s/\%LIB\%/$self->{libdir}/gx;

#     if ($op eq '=')
#     {
#         $self->{ASSIGNMENT_DATA}->{$name} = [$op, $value];
#     }
#     elsif ($op eq '+=')
#     {
#         my $data = $self->get_assignment_value($name);
#         $self->{ASSIGNMENT_DATA}->{$name} = [$op,
#                                              ref $data eq 'ARRAY' ? [@{$data}, $value] :
#                                              $data                ? [$data, $value] :
#                                                                     [$value]];
#     }
#     else
#     {
#         $self->{SELECT_DATA}->{$name} = [$op, $value];
#     }

#     return;
# }

# sub get_select_data_names
# {
#     my $self = shift;

#     return [keys %{$self->{SELECT_DATA}}];
# }

# sub get_select_data_values
# {
#     my $self = shift;
#     my $name = shift;

#     return @{$self->{SELECT_DATA}->{$name}};
# }

# sub get_select_op
# {
#     my $self = shift;
#     my $name = shift;

#     return ${$self->{SELECT_DATA}->{$name}}[0];
# }

# sub get_select_value
# {
#     my $self = shift;
#     my $name = shift;

#     return ${$self->{SELECT_DATA}->{$name}}[1];
# }

# sub get_assignment_data_names
# {
#     my $self = shift;

#     return [keys %{$self->{ASSIGNMENT_DATA}}];
# }

# sub get_assignment_data_values
# {
#     my $self = shift;
#     my $name = shift;

#     return @{$self->{ASSIGNMENT_DATA}->{$name}};
# }

# sub get_assignment_op
# {
#     my $self = shift;
#     my $name = shift;

#     return ${$self->{ASSIGNMENT_DATA}->{$name}}[0];
# }

# sub get_assignment_value
# {
#     my $self = shift;
#     my $name = shift;

#     return ${$self->{ASSIGNMENT_DATA}->{$name}}[1];
# }

# sub myname
# {
#     my $self = shift;
#     my $name = shift || '';

#     $self->{MYNAME} = $name if $name;

#     return $self->{MYNAME};
# }

# sub add_node
# {
#     my $self = shift;
#     my $nodename = shift;
#     my $node = shift;

#     $self->{NODE}->{$nodename} = $node;
#     $node->myname($nodename);

#     return;
# }

# sub get_children
# {
#     my $self = shift;
#     my @nodelist;

#     foreach my $nodename (sort keys %{$self->{NODE}})
#     {
#         push(@nodelist, $self->{NODE}->{$nodename});
#     }

#     return \@nodelist;
# }


# # If the block has no SELECT_DATA, then
# #   match should succeed (return 1)
# # else
# #   if everything in the block's SELECT_DATA is matched (that is,
# #               the passed-in selectors may have more keys, but as
# #               long as everything that the block looks for is satisfied)
# #               then
# #      match succeeds (return 1)
# #   else   (there was at least one selector in SELECT_DATA that was
# #           not matched by the passed-in selectors)
# #      match fails (return 0)
# #
# sub evaluate
# {
#     my $self = shift;
#     my $select_list = shift;
#     my $retval = 1;
#     my $dupval;

#     # We can pass in a Record as a selector
#     $select_list = $select_list->get_selectors() if ref $select_list eq 'Idval::Record';

#     if (ref $select_list ne 'HASH')
#     {
#         confess "Selector list must be a HASH\n";
#     }

#     # If the block has no selector keys itself, then all matches should succeed
#     if (!exists($self->{SELECT_DATA}))
#     {
#         verbose("Eval: returning 1 since no SELECT_DATA\n") if $self->{DEBUG};
#         return 1;
#     }

#     my  %selectors = %{$select_list};

#     return 0 unless %selectors;

#     chatty ("In node \"", $self->myname(), "\"\n") if $self->{DEBUG};
#     print Dumper($self) unless $self->myname();

#     foreach my $block_key (@{$self->get_select_data_names()})
#     {
#         chatty ("Checking block selector \"$block_key\"\n");
#         if (!exists($select_list->{$block_key}))
#         {
#             # The select list has nothing to match a required selector, so this must fail
#             return 0;
#         }

#         my $arg_value_list = ref $selectors{$block_key} eq 'ARRAY' ? $selectors{$block_key} : [$selectors{$block_key}];
#         # Now, arg_value is guaranteed to be a list reference

#         my $block_op = $self->get_select_op($block_key);
#         my $block_value = $self->get_select_value($block_key);
#         my $block_cmp_func = Idval::Select::get_compare_function($block_op, 'STR');
#         my $cmp_result = 0;

#         # For any key, the passed_in selector may have a list of values that it can offer up to be matched.
#         # A successful match for any of these values constitutes a successful match for the block selector.
#         foreach my $value (@{$arg_value_list})
#         {
#             chatty ("Comparing \"$value\" \"$block_op\" \"$block_value\" resulted in ",
#                     &$block_cmp_func($value, $block_value) ? "True\n" : "False\n") if $self->{DEBUG};

#             $cmp_result ||= &$block_cmp_func($value, $block_value);
#             last if $cmp_result;
#         }

#         $retval &&= $cmp_result;
#         last if !$retval;
#     }

#     chatty ("evaluate returning $retval\n") if $self->{DEBUG};
#     return $retval;



# #     foreach my $key (keys %selectors)
# #     {
# #         chatty ("Checking select key \"$key\" with a value of \"", Dumper($selectors{$key}), "\"\n") if $self->{DEBUG};
# #         if (!exists($self->{SELECT_DATA}->{$key}))
# #         {
# #             return 0;
# #         }
# #         else
# #         {
# #             chatty ("For select key of \"$key\", got value(s) of \"", Dumper($selectors{$key}), "\"\n") if $self->{DEBUG};
# #         }

# #         my $sel_value = ref $selectors{$key} eq 'ARRAY' ? $selectors{$key} : [$selectors{$key}];
# #         my $cmp_op = $self->get_select_op($key);
# #         my $cmp_value = $self->get_select_value($key);
# #         my $cmpfunc = Idval::Select::get_compare_function($cmp_op, 'STR');
# #         my $cmp_result = 0;
# #         foreach my $value (@{$sel_value})
# #         {
# #             chatty ("Comparing \"$cmp_value\" \"$cmp_op\" \"$value\" resulted in ",
# #                     &$cmpfunc($value, $cmp_value) ? "True\n" : "False\n") if $self->{DEBUG};

# #             $cmp_result ||= &$cmpfunc($value, $cmp_value);
# #             last if $cmp_result;
# #         }

# #         $retval &&= $cmp_result;
# #         last if !$retval;
# #     }

# #     chatty ("evaluate returning $retval\n") if $self->{DEBUG};
# #     return $retval;
# }

1;
