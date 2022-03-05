package Idval::Graph;

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

# TODO:
#  process_graph should probably just go ahead and extract the best paths right there.

use strict;
use warnings;
use Data::Dumper;
use List::Util;

use Idval::Logger qw(verbose chatty idv_dbg fatal);
use Idval::Common;

my @path_list;
my $extracted_paths = {};

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
    my @attrs = ('weight', @_);

    $self->{START_NODES}->{$from} = 1;
    $self->{START_NODES}->{$to} = 1;
    $self->{GRAPH}->{$from}->{$type}->{LINK} = 1;
    $self->{GRAPH}->{$from}->{$type}->{WEIGHT} = $weight;
    $self->{GRAPH}->{$from}->{$type}->{VISITED} = 0;
    $self->{GRAPH}->{$type}->{$to}->{LINK} = 1;
    $self->{GRAPH}->{$type}->{$to}->{WEIGHT} = $weight;
    $self->{GRAPH}->{$type}->{$to}->{VISITED} = 0;

    foreach my $attr (@attrs)
    {
        $self->{GRAPH}->{$from}->{$type}->{ATTRS}->{$attr} = 1;
        $self->{GRAPH}->{$type}->{$to}->{ATTRS}->{$attr} = 1;
    }

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

sub clear_all_visited
{
    my $self = shift;

    foreach my $a (keys %{$self->{GRAPH}})
    {
        foreach my $b (keys %{$self->{GRAPH}->{$a}})
        {
            $self->{GRAPH}->{$a}->{$b}->{VISITED} = 0;
        }
    }

    return;
}

#
# Also get a list of attributes that are in all members of a path
#
# This routine goes through all the paths (found by do_walk), and
# calculates (and saves) certain properties of the paths. These
# properties are:
#   total weight of the path (which is the sum of the weights of each
#         arc in the path).
#   presence of certain attributes, namely 'transcode' and 'filter' (someday)
sub get_paths
{
    my $self = shift;

    my $num_paths;
    my $path_index;
    my $path_weight;
    my @list;
    my ($start, $type, $end);
    my %attrs;

    # A PATH_LIST is a list of nodes. Each PATH_LIST starts and ends
    # with a major node, and alternates major nodes (end types) with
    # minor nodes (converters). So: WAV->flac->FLAC->ogg->OGG, or
    # WAV->copy->WAV.

    foreach my $list (@{$self->{PATH_LIST}})
    {
        my %path_info;
        verbose("Inspecting ([_1]); length is: [_2]\n", join(',', @{$list}), scalar(@{$list})); ##debug1
        # We don't want just a NODEX->NODEX loop (it must be at least NODEX->converter->NODEX).
        next if scalar(@{$list}) <= 1;
        #%path_info = ();
        $num_paths = (scalar(@{$list}) - 1) / 2;
        $path_index = 0;
        $path_weight = 0;
        $start = ${$list}[0];
        $type = ${$list}[1];
        $end = ${$list}[-1];
        $path_info{START} = $start;
        $path_info{END} = $end;

        #%attrs = (%{$self->{GRAPH}->{$start}->{$type}->{ATTRS}});
        my %attrs = ();
        #verbose("Initial attributes are: [_1]\n", join(':', sort keys %attrs)); ##debug1

        for (my $i = 0; $i < $num_paths; $i++)
        {
            ($start, $type, $end) = @{$list}[$path_index .. $path_index+2];
            push(@{$path_info{PATHS}}, [$start, $type, $end]);
            $path_weight += $self->{GRAPH}->{$start}->{$type}->{WEIGHT};
            $path_weight += $self->{GRAPH}->{$type}->{$end}->{WEIGHT};
            verbose("Got: ([_1], [_2], [_3])\n", $start, $type, $end); ##debug1

            # Only one path arc needs an attribute for the whole path
            # to have that attribute.

            foreach my $attr (keys %{$self->{GRAPH}->{$start}->{$type}->{ATTRS}})
            {
                $attrs{$attr} = $self->{GRAPH}->{$start}->{$type}->{ATTRS}->{$attr}; # This will probably always only be 1
            }

            verbose("In loop: attributes are: [_1]\n", join(':', sort keys %attrs)); ##debug1
            $path_index += 2;
        }

        $path_info{WEIGHT} = $path_weight;
        # $path_info{ATTRS} is a hash of the attributes shared by all members of the list.
        # There will always be a 'weight' attribute; there may or may not be any others.
        $path_info{ATTRS} = {%attrs}; # be sure to make a copy
        #idv_dbg("Storing into [_1].[_2]: [_3]", $path_info{START}, $path_info{END}, Dumper(\%path_info)); ##Dumper
        push(@{$self->{EXTRACTED_PATHS}->{$path_info{START} . '.' . $path_info{END}}}, \%path_info);
        verbose("\n"); ##debug1
    }

    return;
}

# This routine finds and stores all the possible valid paths
sub do_walk
{
    my $self = shift;

    #local @current_path;

    foreach my $item (keys %{$self->{START_NODES}})
    {
        verbose("Starting with node \"[_1]\"\n", $item); ##debug1
        $self->walkit($item, $self->{GRAPH}, 1);
        verbose("Clearing all visited stickers from nodes\n"); ##debug1
        $self->clear_all_visited();
    }

#     foreach my $list (@{$self->{PATH_LIST}})
#     {
#         #verbose("([_1])\n", join(',', @{$list})); ##debug1
#     }

    return;
}

#
# Given a node
#X   If this node is in the current node path
#X      return (it's a loop)
#   save current_path
#   add this node to the current path
#   If this is a major node
#      add the path from the starting node to this node to the path list
#   For each link that leads away from the node AND that has not yet been used
#      Mark link as used
#      Call this routine with the new node
#
#   restore current_path;

sub walkit
{
    my $self = shift;

    my $item = shift;
    my $gakker = shift;
    my $level = shift;

    my ($short_item) = ($item =~ m/([^:]+)$/);
    my @saved_path = (@{$self->{CURRENT_PATH}});

    #verbose("[_1]Checking \"[_2]\" against [_3]", $leader x $level, $short_item, $self->path_as_str()); ##Dumper
    if (defined(${$self->{CURRENT_PATH}}[0]) and ($item eq ${$self->{CURRENT_PATH}}[0]))
    {
        # Let's allow loops back to the start
        # But make sure it really is to the start
        #verbose("[_1]Found a loop: [_2]", $leader x $level, Dumper($self->{CURRENT_PATH})); ##Dumper
        fatal("Beginning of current path \([_1]\) is not a START_NODE\n", $short_item) unless $self->is_major_node($item);
    }
#     elsif (List::Util::first { $item eq $_ } @{$self->{CURRENT_PATH}})
#     {
#         verbose("[_1]Found an internal loop. Returning.\n", $leader x $level); ##debug1
#         return;
#     }

    # Mark the link from wherever we were last to here as visited.
    if(scalar(@{$self->{CURRENT_PATH}}) > 1)
    {
        my $from_item = ${$self->{CURRENT_PATH}}[-1];
        # This is to prevent the walkit routine from looping around
        # filters. It doesn't work to just mark everything we've
        # visited as 'visited', since that prevent us from getting:
        # A->foo->B->goo->C if we've already got
        # A->foo->B->filter->B->goo->C
        if (exists $self->{GRAPH}->{$from_item}->{$item}->{ATTRS}->{filter})
        {
            idv_dbg("Marking [_1] to [_2] as visited.\n", $from_item, $item); ##debug1
            $self->{GRAPH}->{$from_item}->{$item}->{VISITED} = 1;
        }
    }
    push(@{$self->{CURRENT_PATH}}, $item);

    #if (List::Util::first { $item eq $_ } keys %{$self->{START_NODES}})
    # If there is is more than one node in the path, and
    # the path begins and ends on a major node, then consider saving it
    if ($self->is_major_node($item))
    {
        if (scalar(@{$self->{CURRENT_PATH}}) > 1)
        {
            # Should we bother saving this?
            if(!$self->has_duplicate_nodes($self->{CURRENT_PATH}, $leader x $level))
            ##if ($self->is_lighter_than_max($self->{CURRENT_PATH}))
            {
                #verbose("[_1]Saving current path [_2]", $leader x $level, $self->path_as_str()); ##Dumper
                push(@{$self->{PATH_LIST}}, [@{$self->{CURRENT_PATH}}]);
            }
            else
            {
                #verbose("[_1]Current path has illegal duplicate nodes: [_2]", $leader x $level, $self->path_as_str()); ##Dumper
                return;
            }
        }
        else
        {
            #verbose("[_1]Current path is too short to save: [_2]", $leader x $level, $self->path_as_str()); ##Dumper
        }
    }

    #verbose("[_1]Will travel from \"[_2]\" to: ([_3])\n", $leader x $level, $short_item, join(',', keys %{$gakker->{$item}})); ##debug1
    #verbose("[_1]Will travel from \"[_2]\" to: [_3]", $leader x $level, $short_item, $self->path_as_str({path => [ keys %{$gakker->{$item}}]})); ##Dumper
    foreach my $next (keys %{$gakker->{$item}})
    {
        my ($short_next) = ($next =~ m/([^:]+)$/);
        if ($self->{GRAPH}->{$item}->{$next}->{VISITED})
        {
            verbose("[_1]\"[_2]\" to \"[_3]\" has already been visited.\n", $leader x $level, $short_item, $short_next); ##debug1
        }
        else
        {
            verbose("[_1]Going from \"[_2]\" to \"[_3]\"\n", $leader x $level, $short_item, $short_next); ##debug1
            $self->walkit($next, $gakker, ($level + 1));
        }
    }

    #verbose($leader x $level, "[_1]Restoring [_2] to ([_3])\n", $leader x $level, $self->path_as_str({trailer => ''}), join(',', @saved_path)); ##Dumper
    #verbose($leader x $level, "[_1]Restoring [_2] to ([_3])\n", $leader x $level, $self->path_as_str({trailer => ''}), $self->path_as_str({path => \@saved_path})); ##Dumper
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

# Generally, a path may not have duplicate major nodes, with one (big)
# exception: MN->type->[->X->]*->MN is ok. For instance, A->foo->A is
# OK, A->foo->A->garf->B is not. A->garf->B->harf->A is OK, but
# A->garf->B->larf->B->carf->A is not.

# This will need to be modified to allow (in the above) 'B->larf->B',
# but only if 'larf' has a 'filter' attribute. It will also need to
# make sure that there is only one 'larf' in the path. Note that
# different filters should be OK (that is, (in the above) one of
# 'B->marf->B', with 'marf' being a filter, should be OK also).
#
# So, with the notation that 'arf' is a converter that does not have a
# 'filter' attribute, and 'arf&' is a converter with a filter
# attribute:
#
#  OK:     MN->type->[->X->]*->MN
#  OK:     A->garf->B->harf->A
#  NOT OK: A->garf->B->larf->B->carf->A            (same major nodes inside)
#  OK:     A->garf->B->larf&->B->carf->A           (same major nodes,
#                                                   but through a filter)
#  NOT OK: A->garf->B->larf&->B->larf&->B->carf->A (two of the same filter)
#  OK:     A->garf->B->larf&->B->marf&->B->carf->A (different filters)

sub old_has_duplicate_nodes
{
    my $self = shift;
    my $path = shift;

    my @pl = @{$path};
    my %phash = ();

    my $first = $pl[0];
    my $last = $pl[-1];

    if ($first eq $last)
    {
        # Fake out the next loop by removing the last element, which
        # is licit, if a duplicate.
        pop @pl;
    }

    foreach my $node (@pl)
    {
        $phash{$node}++ if $self->is_major_node($node);
        return 1 if (exists $phash{$node} && ($phash{$node} > 1)); # We have a duplicate!
    }

    return 0;
}

#  NOT OK: A->garf->B->larf&->B->larf&->B->carf->A (two of the same filter)
#  OK:     A->garf->B->larf&->B->marf&->B->carf->A (different filters)
sub has_duplicate_nodes
{
    my $self = shift;
    my $path = shift;
    my $leader = shift;

    my @pl = @{$path};
    my ($start, $type, $end);
    my %phash = ();
    my $begin = $pl[0];

    #idv_dbg("[_1]Checking for duplicate nodes in [_2]", $leader, $self->path_as_str({path=>$path})); ##Dumper

    # Special case: A path that contains only one arc cannot have any
    # invalid duplicate nodes.
    idv_dbg("[_1]One-arc path; must be OK for dup nodes\n", $leader) if $#pl == 2; ##debug1
    return 0 if $#pl == 2;

    $phash{$pl[0]}++;

  NODES:
    # Step through the nodes, looking at each arc. An arc consists of
    # (edge-node -> type-node -> edge-node). Since arc n shares its
    # end node with arc n+1's start node, this means that edge-nodes
    # always have an even index, and type-nodes always have an odd
    # index.
    # Also, since it's OK for a _path_ to have the same start and end
    # nodes, we don't need to check the last node of the path (that's
    # why the following loop only goes up to $#pl-1).
    for my $i (0 .. $#pl-1)
    {
        next NODES if $i % 2; # skip the odd ones (= 'type' nodes)

        ($start, $type, $end) = @pl[$i .. $i+2];

        if (($i+2 == $#pl) and ($end eq $begin))
        {
            # This is the last node and it is the same as the beginning node.
            # This is OK.
            last NODES;
        }

        $phash{$end}++;

        # Note that attributes only apply to the type-node, and (so)
        # the ATTR element for $self->{GRAPH}->{$start}->{$type} is
        # the same as the ATTR element for
        # $self->{GRAPH}->{$type}->{$end}, so we only have to look at
        # one of them.

        if ($phash{$end} > 1)
        {
            # We found a duplicate. Is it OK?
            idv_dbg("[_1]Checking dup node [_2]\n", $leader, $end); ##debug1
            # There is only one case where it could be OK. If, for a
            # given arc, the start node is the same as the end node,
            # and the type-node is a filter.
            if (($start eq $end) and
                exists $self->{GRAPH}->{$start}->{$type}->{ATTRS}->{filter})
            {
                $phash{$end} = 1;
                idv_dbg("[_1]Dup node is OK ($start->$end)\n");
                next NODES;
            }

            idv_dbg("[_1]Bad duplicate node found for \"$start\" -> \"$end\"\n");
            #idv_dbg("[_1]ATTRS: ", Dumper($self->{GRAPH}->{$start}->{$type}->{ATTRS})); ##Dumper
            return 1;           # We have an invalid duplicate
        }
    }

    return 0;
}

sub is_lighter_than_max
{
    my $self = shift;
    my $path = shift;

    my $weight = $self->get_path_weight($path);
    my $first = ${$path}[0];
    my $last = ${$path}[-1];

    if (exists($self->{GREATEST_PATH_WEIGHTS}->{$first}) && exists($self->{GREATEST_PATH_WEIGHTS}->{$first}->{$last}))
    {
        my $max_weight = $self->{GREATEST_PATH_WEIGHTS}->{$first}->{$last};
        if ($max_weight < $weight)
        {
            return 0;
        }
    }

    $self->{GREATEST_PATH_WEIGHTS}->{$first}->{$last} = $weight;

    return 1;
}

#
# It is incorrect to require all paths to have the attribute(s). This
# will always result in skipping (due to path weight) the node that
# actually does the (say) filtering, since that will be a node of the
# form 'A'->filter->'A', and so will add weight and be de-selected.
#
# It should be the case that (at least) one must have the
# attribute. If there is more than one attribute, it is not required
# (and probably won't be the case) that one path has both.
#
# humm, transcode is only applicable to A->A paths; for paths between
# different endpoints, say B->A, it can always be handled by the
# converter that encodes to A (I think).
# Filters are a different matter, since they are only applicable to
# paths that go through the filter; this may (of course) include paths
# that start and end with the same type: A->(filter)->A, or anything:
# B->(filter)->A. The filters, I would imagine, would work on WAV
# files.
# We would then need to get paths like:
# A->{a_to_wav}->WAV->{filter}->WAV->{wav_to_b}->B. Clearly, the only
# arc with a 'filter' attribute would be the WAV->{filter}->WAV arc.
#
# To get this to work the 'has_duplicate_nodes' routine must be
# modified to allow internal 'loops' that have the filter property,
# but must be careful to avoid an infinite loop.

sub get_best_path
{
    my $self = shift;
    my $from = shift;
    my $to   = shift;
    my @attrs = sort ('weight', defined (@_) ? @_ : ());
    my $arc = $from . '.' . $to;
    my @goodpaths = ();

    $self->process_graph();

    verbose("Looking for path: \"[_1]\"\n", $arc); ##debug1
    if(!exists($self->{EXTRACTED_PATHS}->{$arc}))
    {
        chatty("Path: \"[_1]\" does not exist in EXTRACTED_PATHS\n", $arc); ##debug1
        return;
    }

    # Get a list of all the paths that have all the required attributes
    #chatty("Getting best path from: [_1]", Dumper($self->{EXTRACTED_PATHS}->{$arc})); ##Dumper
    chatty("Need attributes: [_1]\n", join(',', @attrs)); ##debug1
  CHECK_PATHS:
    foreach my $pathinfo (@{$self->{EXTRACTED_PATHS}->{$arc}})
    {
        idv_dbg("Path \"[_1].[_2] has attributes: [_3]\n",  $pathinfo->{START}, $pathinfo->{END},
                join(',', sort keys %{$pathinfo->{ATTRS}})); ##debug1

        foreach my $attr (@attrs)
        {
            if (!exists($pathinfo->{ATTRS}->{$attr}))
            {
                idv_dbg("Path [_1] does not have attribute [_2], checking next path.\n", $arc, $attr); ##debug1
                next CHECK_PATHS;
            }
        }

        push(@goodpaths, $pathinfo);
    }

    #idv_dbg("Resulting path list is: [_1]", Dumper(\@goodpaths)); ##Dumper

    #
    # Sort in order of weight
    # Less weight is better (means a shorter path)

    my @sorted =
    map  { $_->[1] }
    sort { $a->[0] <=> $b->[0] }
    map  { [ $_->{WEIGHT}, $_ ] }
    @goodpaths;

    my @result = map { $_->{PATHS} } @sorted;
    return $result[0];
}

sub path_as_str
{
    my $self = shift;
    my $argref = shift;
    my @path = exists $argref->{path} ? (@{$argref->{path}}) : (@{$self->{CURRENT_PATH}});
    my $trailer = exists $argref->{trailer} ? $argref->{trailer} : "\n";
    my $full    = exists $argref->{full} ? $argref->{full} : 0;

    #@path = map { $_ =~ s/([^:]+::)+//g } @path if !$full;
    @path = map { ( $_ =~ m/([^:]+)$/) } @path if !$full;
#     if (!$full)
#     {
#         my @temp = (@path);
#         @path = ();
#         foreach my $item (@temp)
#         {
#             print STDERR "old item: $item\n";
#             $item =~ s/([^:]+::)+//g;
#             print STDERR "new item: $item\n";
#             push(@path, $item);
#         }
#     }

    return '(', join(',', @path), ')' . $trailer;
}

1;
