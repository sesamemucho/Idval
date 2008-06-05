package Idval::NGraph;

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
use List::Util;
use Carp;

my @path_list;
my $extracted_paths = {};

my $greatest_path_weights = {};

my $leader = '  ';

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

    @{$self->{CURRENT_PATH}} = ();
#     @{$self->{START_NODES}} = ('A', 'B', 'W', 'F', 'O', 'M');

#     $self->add_edge('A', 'foo', 'B', 100);
#     $self->add_edge('A', 'boo', 'B', 50);
#     $self->add_edge('B', 'goo', 'W', 100);
#     $self->add_edge('W', 'hoo', 'M', 100);
#     $self->add_edge('W', 'ioo', 'F', 100);
#     $self->add_edge('W', 'joo', 'O', 100);
#     $self->add_edge('F', 'koo', 'W', 100);
#     $self->add_edge('F', 'loo', 'O', 100);
#     $self->add_edge('O', 'moo', 'W', 100);
#     $self->add_edge('M', 'noo', 'W', 100);

    return;
}

sub add_edge
{
    my $self = shift;

    my $from = shift;
    my $type = shift;
    my $to = shift;
    my $weight = shift;

    $self->{START_NODES}->{$from} = 1;
    $self->{START_NODES}->{$to} = 1;
    $self->{GRAPH}->{$from}->{$type}->{LINK} = 1;
    $self->{GRAPH}->{$from}->{$type}->{WEIGHT} = $weight;
    $self->{GRAPH}->{$type}->{$to}->{LINK} = 1;
    $self->{GRAPH}->{$type}->{$to}->{WEIGHT} = $weight;

    return;
}

sub is_major_node
{
    my $self = shift;
    my $node = shift;

    return exists($self->{START_NODES}->{$node});
}

sub is_minor_node
{
    my $self = shift;
    my $node = shift;

    return !exists($self->{START_NODES}->{$node});
}

sub get_paths
{
    my $self = shift;

    my $num_paths;
    my $path_index;
    my $path_weight;
    my @list;
    my ($start, $type, $end);

    foreach my $list (@{$self->{PATH_LIST}})
    {
        my %path_info;
        print "Inspecting (", join(',', @{$list}), "); length is: ", scalar(@{$list}), "\n";
        # We don't want just a NODEX->NODEX loop (it must be at least NODEX->converter->NODEX).
        next if scalar(@{$list}) <= 1;
        #%path_info = ();
        $num_paths = (scalar(@{$list}) - 1) / 2;
        $path_index = 0;
        $path_weight = 0;
        $path_info{START} = ${$list}[0];
        $path_info{END} = ${$list}[-1];

        for (my $i = 0; $i < $num_paths; $i++)
        {
            ($start, $type, $end) = @{$list}[$path_index .. $path_index+2];
            push(@{$path_info{PATHS}}, [$start, $type, $end]);
            $path_weight += $self->{GRAPH}->{$start}->{$type}->{WEIGHT};
            $path_weight += $self->{GRAPH}->{$type}->{$end}->{WEIGHT};
            print "Got: ($start, $type, $end)\n";
            $path_index += 2;
        }

        $path_info{WEIGHT} = $path_weight;
        push(@{$self->{EXTRACTED_PATHS}->{$path_info{START} . '.' . $path_info{END}}}, \%path_info);
    }
    #print Dumper($self);

    return;
}

sub do_walk
{
    my $self = shift;

    #local @current_path;

    foreach my $item (keys %{$self->{START_NODES}})
    {
        print "Starting with node \"$item\"\n";
        $self->walkit($item, $self->{GRAPH}, 1);
    }

    #print Dumper($self);
#     foreach my $list (@{$self->{PATH_LIST}})
#     {
#         #print "(", join(',', @{$list}), ")\n";
#     }

    return;
}

#
# Given a node
#   If this node is in the current node path
#      return (it's a loop)
#   save current_path
#   add this node to the current path
#   If this is a major node
#      add the path from the starting node to this node to the path list
#   For each link that leads away from the node
#      Call this routine with the new node
#
#   restore current_path;

sub walkit
{
    my $self = shift;

    my $item = shift;
    my $gakker = shift;
    my $level = shift;

    my @saved_path = (@{$self->{CURRENT_PATH}});
    
    print $leader x $level, "Checking \"$item\" against (", join(',', @{$self->{CURRENT_PATH}}), ")\n";
    if (defined(${$self->{CURRENT_PATH}}[0]) and ($item eq ${$self->{CURRENT_PATH}}[0]))
    {
        # Let's allow loops back to the start
        # But make sure it really is to the start
        print $leader x $level, "Found a loop: ", Dumper($self->{CURRENT_PATH});
        croak("Beginning of current path \($item\) is not a START_NODE\n") unless $self->is_major_node($item);
    }
    elsif (List::Util::first { $item eq $_ } @{$self->{CURRENT_PATH}})
    {
        print $leader x $level, "Found an internal loop. Returning.\n";
        return;
    }

    push(@{$self->{CURRENT_PATH}}, $item);

    #if (List::Util::first { $item eq $_ } keys %{$self->{START_NODES}})
    if ($self->is_major_node($item))
    {
        # Should we bother saving this?
        if ($self->is_lighter_than_max($self->{CURRENT_PATH}))
        {
            print $leader x $level, "Saving current path ", join(',', @{$self->{CURRENT_PATH}}),"\n";
            push(@{$self->{PATH_LIST}}, [@{$self->{CURRENT_PATH}}]);
        }
        else
        {
            print $leader x $level, "Current path is too heavy to save ", join(',', @{$self->{CURRENT_PATH}}),"\n";
            return;
        }
    }

    print $leader x $level, "Will travel from \"$item\" to: (", join(',', keys %{$gakker->{$item}}), ")\n";
    foreach my $next (keys %{$gakker->{$item}})
    {
        print $leader x $level, "Going from \"$item\" to \"$next\"\n";
        $self->walkit($next, $gakker, ($level + 1));
    }

    print $leader x $level, "Restoring (", join(',', @{$self->{CURRENT_PATH}}), ') to (', join(',', @saved_path), ")\n";
    @{$self->{CURRENT_PATH}} = (@saved_path);

    return;
}

sub process_graph
{
    my $self = shift;

    if (!exists($self->{PATH_LIST}))
    {
        $self->do_walk();
        $self->get_paths();
    }

    return;
}

# Return the total weight for all the edges in the path
# A path is expected to be: Major node, {action, Major node}*
sub get_path_weight
{
    my $self = shift;
    my $path = shift;
    my $weight = 0;
    my @tpath = (@{$path});

    my $node = shift @tpath;
    my $action;

    while(@tpath)
    {
        $action = shift @tpath;
        $weight += $self->{GRAPH}->{$node}->{$action}->{WEIGHT};

        $node = shift @tpath;
        $weight += $self->{GRAPH}->{$action}->{$node}->{WEIGHT};
    }

    return $weight;
}

sub is_lighter_than_max
{
    my $self = shift;
    my $path = shift;

    my $weight = $self->get_path_weight($path);
    my $first = ${$path}[0];
    my $last = ${$path}[-1];

    if (exists($greatest_path_weights->{$first}) && exists($greatest_path_weights->{$first}->{$last}))
    {
        my $max_weight = $greatest_path_weights->{$first}->{$last};
        if ($max_weight < $weight)
        {
            return 0;
        }
    }

    $greatest_path_weights->{$first}->{$last} = $weight;

    return 1;
}


sub get_best_path
{
    my $self = shift;
    my $from = shift;
    my $to   = shift;

    $self->process_graph();

    #print "Looking for path: \"", $from . '.' . $to, "\"\n";
    if(!exists($self->{EXTRACTED_PATHS}->{$from . '.' . $to}))
    {
        return;
    }

    # Sort in order of weight
    # Less weight is better (means a shorter path)

    #print STDERR "1 paths for ", $from . '.' . $to, " are: ", Dumper($self->{EXTRACTED_PATHS}->{$from . '.' . $to});

    #print STDERR "2 paths for ", $from . '.' . $to, " are: ", Dumper($paths);
    #print STDERR "3 paths for ", $from . '.' . $to, " are: ", Dumper($self->{EXTRACTED_PATHS}->{'A.W'});

    #print STDERR "4 size is: ", scalar(@{$paths}), "\n";

    my @sorted = 
    map  { $_->[1] }
    sort { $a->[0] <=> $b->[0] }
    map  { [ $_->{WEIGHT}, $_ ] }
    @{$self->{EXTRACTED_PATHS}->{$from . '.' . $to}};

    my @result = map { $_->{PATHS} } @sorted;
    return $result[0];
}


1;
