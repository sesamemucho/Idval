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
use Carp;
use Memoize;
use Text::Balanced qw (
                       extract_delimited
                       extract_multiple
                      );

use Idval::Common;
use Idval::Constants;
use Idval::Select;
use Idval::FileIO;

use constant STRICT_MATCH => 0;
use constant LOOSE_MATCH  => 1;

our $DEBUG = 0;
our $USE_LOGGER = 1;

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

# Make a flat list out of the arguments, which may be scalars or array refs
# Leave out any undefined args.
sub make_flat_list
{
    my @result = map {ref $_ eq 'ARRAY' ? @{$_} : $_ } grep {defined($_)} @_;
    #harfo ("make_flat list: result is: ", Dumper(\@result));
    return \@result;
}

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
    my $unmatched_selector_keys_ok = shift;
    my $init_debug = shift || 0;

    #$unmatched_selector_keys_ok = STRICT_MATCH unless defined($unmatched_selector_keys_ok);
    $unmatched_selector_keys_ok = 0;
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

    $self->{OP_REGEX} = Idval::Select::get_op_regex();
    $self->{ASSIGN_OP_REGEX} = Idval::Select::get_assign_regex();
    $self->{CMP_OP_REGEX} = Idval::Select::get_cmp_regex();
    $self->{INITFILES} = [];
    $self->{TREE} = {};
    $self->{DEBUG} = $init_debug;
    $self->{USK_OK} = $unmatched_selector_keys_ok;

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
    return unless $initfile;      # Blank input file names are OK...
    push(@{$self->{INITFILES}}, $initfile);

    my $text = '';
    my $fh;

    foreach my $fname (@{$self->{INITFILES}})
    {
        $fh = Idval::FileIO->new($fname, "r") || do {print STDERR Carp::shortmess("shormess");
                                                     croak "Can't open \"$fname\" for reading: $! in " . __PACKAGE__ . " line(" . __LINE__ . ")";};
        $text .= do { local $/ = undef; <$fh> };
        $fh->close();
    }

    croak "Need a file" unless $text; # We do need at least one config file

    $text =~ s/^\s*#.*$//mgx;      # Remove comments
    $text =~ s/^\n+//sx;         # Trim off newline(s) at start
    $text =~ s/\n+$//sx;         # Trim off newline(s) at end


    $self->{NODENAME} = 'Node0000';
    my $top = $self->parse_blocks("\{$text\}");
    $self->{TREE} = $top->{NODE}->{'Node0000'};

    return;
}

sub get_next_nodename
{
    my $self = shift;
    my $newnode = $self->{NODENAME}++;
    chatty ("returning nodename $newnode\n") if $self->{DEBUG};
    return $newnode;
}

sub extract_blocks
{
    my $self = shift;
    my $text = shift;

    my @blocks;
    my ($extracted, $remainder, $skipped);
    my $front = '';

    chatty ("in extract_blocks\n") if $self->{DEBUG};
    while(1)
    {
        ($extracted, $remainder, $skipped) = Text::Balanced::extract_codeblock($text, '{}', '[^{}]*');
        chatty ("extracted: \"$extracted\", remainder is: \"$remainder\", skipped: \"$skipped\"\n") if $self->{DEBUG};

        last unless $extracted;

        push(@blocks, $extracted);

        $text = $remainder;
        $front .= $skipped;
    }

    $remainder = $front . $remainder;
    chatty ("** blocks are: ", join('::', @blocks), "   remainder is: \"$remainder\"\n") if $self->{DEBUG};
    return (\@blocks, $remainder);
}

sub parse_one_block
{
    my $self = shift;
    my $node = shift;
    my $text = shift;

    my $op_regex = $self->{OP_REGEX};

    my $current_tag = undef;
    my $current_op;
    my $current_value;

    return unless defined $text; # Nothing to do...

    chatty ("parse_one_block, op_regex is: \"$op_regex\"\ndata is: <$text>\n") if $self->{DEBUG};

    foreach my $line (split(/\n/x, $text))
    {
        chomp $line;
        $line =~ s{\r}{}gx;
        $line =~ s/\#.*$//x;      # Remove comments
        next if $line =~ m/^\s*$/x;

        if ($line =~ m{^([[:alnum:]]\w*)($op_regex)(.*)$}imx)
        {
            $node->add_data($current_tag, $current_op, $current_value) if defined $current_tag;
            chatty ("Got tag of \"$1\" \"$2\" \"$3\" \n") if $self->{DEBUG};
            $current_tag = $1;
            $current_op = $2;
            $current_value = $3;

            $current_op =~ s/\s//gx;
            next;
        };

        if ($line =~ m{^\s+(.*)$}imx)
        {
            croak("Found unexpected continuation line \"$line\" at the beginning of a block") unless defined $current_tag;
            chatty ("Got continuation tag of \"$1\" \"$2\" \"$3\" \n") if $self->{DEBUG};
            $current_value .= $3;
            next;
        };

    }

    $node->add_data($current_tag, $current_op, $current_value) if defined $current_tag;

    return;
}

sub parse_blocks
{
    my $self = shift;
    my $text = shift;

    my $tree = Idval::Config::Block->new($self->{DEBUG}, $self->{USK_OK});
    my ($kidsref, $data) = $self->extract_blocks($text);
    my $child_name;
    my $op_regex = $self->{OP_REGEX};

    # Clean it up
    $data =~ s/^\s+//gmx;
    $data =~ s/\s+$//gmx;

    # Preprocess the data, for use in the visit subroutine
    $self->parse_one_block($tree, $data);

    chatty ("Current node has ", scalar(@{$kidsref}), " children.\n") if $self->{DEBUG};
    foreach my $blk (@{$kidsref})
    {
        chop $blk;
        $blk = substr($blk, 1);
        $child_name = $self->get_next_nodename();
        chatty ("At \"$child_name\", Looking at: \"$blk\"\n") if $self->{DEBUG};
        $tree->add_node($child_name, $self->parse_blocks($blk));
    }

    chatty ("tree: ", Dumper($tree)) if $self->{DEBUG};
    return $tree;
}

sub visit
{
    my $self = shift;
    my $top = shift;
    my $subr = shift;

    chatty("visiting ", $top->myname(), "\n");
    my $retval = &$subr($top);

    # If retval is undef, this node is not for us
    # and therefore, none of its children are, either
    chatty("return from subr on ", $top->myname(), " is undef\n") if not defined($retval);
    return if not defined($retval);

    # get_children returns a list of child nodes, sorted
    # by nodename.
    foreach my $node (@{$top->get_children()})
    {
        $self->visit($node, $subr);
    }

    return;
}

sub merge_blocks
{
    my $self = shift;
    my $selects = shift;
    my %vars;

    confess "selects argument required for config call" unless (defined($selects) && $selects);
    verbose ("Start of _merge_blocks, selects: ", Dumper($selects)) if $self->{DEBUG};

    if ($Idval::Config::DEBUG)
    {
        print STDERR "Start of _merge_blocks, selects: ", Dumper($selects);
    }

    # visit each node, in correct order
    # if node evaluates to TRUE,
    #    accumulate values (including appends)

    # When finished with tree, return hash of values

    my $visitor = sub {
        my $node = shift;
        return if $node->evaluate($selects) == 0;

        foreach my $name (@{$node->get_assignment_data_names()})
        {
            my ($op, $value) = $node->get_assignment_data_values($name);
            chatty ("name \"$name\" op \"$op\" value \"$value\"\n") if $self->{DEBUG};

            if ($op eq '=')
            {
                chatty ("For \"$name\", op is \"=\" and value is \"$value\"\n") if $self->{DEBUG};
                $vars{$name} = $value;
            }
            elsif ($op eq '+=')
            {
                chatty ("For \"$name\", op is \"+=\" and value is \"$value\"\n") if $self->{DEBUG};
                $vars{$name} = make_flat_list($vars{$name}, $value);
            }
        }

        return 1;
    };

    $self->visit($self->{TREE}, $visitor);

    chatty ("Result of merge blocks - VARS: ", Dumper(\%vars)) if $self->{DEBUG};

    return \%vars;
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

package Idval::Config::Block;

use strict;
use warnings;
use Data::Dumper;
use English '-no_match_vars';
use Carp;

use Idval::Common;
use Idval::Constants;

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
    my $debug = shift;
    my $unmatched_selector_keys_ok = shift;

    $self->{ASSIGN_OP_REGEX} = Idval::Select::get_assign_regex();
    $self->{datadir} = Idval::Common::get_top_dir('data');
    $self->{libdir} = Idval::Common::get_top_dir('lib');

    $self->{USK_OK} = $unmatched_selector_keys_ok;
    $self->{DEBUG} = $debug;

    return;
}

sub add_data
{
    my $self = shift;
    my $name = shift;
    my $op = shift;
    my $value = shift;

    confess "undef op" unless defined $op;

    $value =~ s/\%DATA\%/$self->{datadir}/gx;
    $value =~ s/\%LIB\%/$self->{libdir}/gx;

    if ($op eq '=')
    {
        $self->{ASSIGNMENT_DATA}->{$name} = [$op, $value];
    }
    elsif ($op eq '+=')
    {
        my $data = $self->get_assignment_value($name);
        $self->{ASSIGNMENT_DATA}->{$name} = [$op,
                                             ref $data eq 'ARRAY' ? [@{$data}, $value] :
                                             $data                ? [$data, $value] :
                                                                    [$value]];
    }
    else
    {
        $self->{SELECT_DATA}->{$name} = [$op, $value];
    }

    return;
}

sub get_select_data_names
{
    my $self = shift;

    return [keys %{$self->{SELECT_DATA}}];
}

sub get_select_data_values
{
    my $self = shift;
    my $name = shift;

    return @{$self->{SELECT_DATA}->{$name}};
}

sub get_select_op
{
    my $self = shift;
    my $name = shift;

    return ${$self->{SELECT_DATA}->{$name}}[0];
}

sub get_select_value
{
    my $self = shift;
    my $name = shift;

    return ${$self->{SELECT_DATA}->{$name}}[1];
}

sub get_assignment_data_names
{
    my $self = shift;

    return [keys %{$self->{ASSIGNMENT_DATA}}];
}

sub get_assignment_data_values
{
    my $self = shift;
    my $name = shift;

    return @{$self->{ASSIGNMENT_DATA}->{$name}};
}

sub get_assignment_op
{
    my $self = shift;
    my $name = shift;

    return ${$self->{ASSIGNMENT_DATA}->{$name}}[0];
}

sub get_assignment_value
{
    my $self = shift;
    my $name = shift;

    return ${$self->{ASSIGNMENT_DATA}->{$name}}[1];
}

sub myname
{
    my $self = shift;
    my $name = shift || '';

    $self->{MYNAME} = $name if $name;

    return $self->{MYNAME};
}

sub add_node
{
    my $self = shift;
    my $nodename = shift;
    my $node = shift;

    $self->{NODE}->{$nodename} = $node;
    $node->myname($nodename);

    return;
}

sub get_children
{
    my $self = shift;
    my @nodelist;

    foreach my $nodename (sort keys %{$self->{NODE}})
    {
        push(@nodelist, $self->{NODE}->{$nodename});
    }

    return \@nodelist;
}

sub evaluate
{
    my $self = shift;
    my $select_list = shift;
    my $retval = 1;
    my $dupval;

    # We can pass in a Record as a selector
    $select_list = $select_list->get_selectors() if ref $select_list eq 'Idval::Record';

    if (ref $select_list ne 'HASH')
    {
        confess "Selector list must be a HASH\n";
    }

    # If the block has no selector keys itself, then all matches should succeed
    if (!exists($self->{SELECT_DATA}))
    {
        verbose("Eval: returning 1 since no SELECT_DATA\n") if $self->{DEBUG};
        return 1;
    }

    my  %selectors = %{$select_list};

    return 0 unless %selectors;

    chatty ("In node \"", $self->myname(), "\"\n") if $self->{DEBUG};
    print Dumper($self) unless $self->myname();
    foreach my $key (keys %selectors)
    {
        chatty ("Checking select key \"$key\" with a value of \"", Dumper($selectors{$key}), "\"\n") if $self->{DEBUG};
        if (!exists($self->{SELECT_DATA}->{$key}))
        {
            next;
        }
        else
        {
            chatty ("For select key of \"$key\", got value(s) of \"", Dumper($selectors{$key}), "\"\n") if $self->{DEBUG};
        }

        my $sel_value = ref $selectors{$key} eq 'ARRAY' ? $selectors{$key} : [$selectors{$key}];
        my $cmp_op = $self->get_select_op($key);
        my $cmp_value = $self->get_select_value($key);
        my $cmpfunc = Idval::Select::get_compare_function($cmp_op, 'STR');
        my $cmp_result = 0;
        foreach my $value (@{$sel_value})
        {
            chatty ("Comparing \"$cmp_value\" \"$cmp_op\" \"$value\" resulted in ",
                    &$cmpfunc($value, $cmp_value) ? "True\n" : "False\n") if $self->{DEBUG};

            $cmp_result ||= &$cmpfunc($value, $cmp_value);
            last if $cmp_result;
        }

        $retval &&= $cmp_result;
        last if !$retval;
    }

    chatty ("evaluate returning $retval\n") if $self->{DEBUG};
    return $retval;
}

1;
