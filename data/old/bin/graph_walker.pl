
use Data::Dumper;
use List::Util;

our @path_list;
our $extracted_paths = {};

$a = {};
# $a = { A => { foo => {LINK => 1},
#               boo => {LINK => 1},
#             },
#        foo => { B => {LINK => 1},
#               },
#        boo => { B => {LINK => 1},
#               },
#        B => { W => {LINK => 1},
#             },
#        W => { M => {LINK => 1},
#               F => {LINK => 1},
#               O => {LINK => 1},
#             },
#        F => { W => {LINK => 1},
#               O => {LINK => 1},
#             },
#        O => { W => {LINK => 1},
#             },
#        M => { W => {LINK => 1},
#             },
#        };

@start_nodes = ('A', 'B', 'W', 'F', 'O', 'M');

add_edge('A', 'foo', B, 100);
add_edge('A', 'boo', B, 50);
add_edge('B', 'goo', W, 100);
add_edge('W', 'hoo', M, 100);
add_edge('W', 'ioo', F, 100);
add_edge('W', 'joo', O, 100);
add_edge('F', 'koo', W, 100);
add_edge('F', 'loo', O, 100);
add_edge('O', 'moo', W, 100);
add_edge('M', 'noo', W, 100);

print "a is ", Dumper($a);

do_walk();

get_paths(\@path_list);

print Dumper($extracted_paths);

sub do_walk
{
    local @current_path;

    foreach my $item (@start_nodes)
    {
        print "Starting with node \"$item\"\n";
        walkit($item, $a);
    }

    foreach my $list (@path_list)
    {
        print "(", join(',', @{$list}), ")\n";
    }
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
    my $item = shift;
    my $gakker = shift;
    my @saved_path = (@current_path);
    
    #print "Checking \"$item\" against (", join(',', @current_path), ")\n";
    if(List::Util::first { $item eq $_ } @current_path)
    {
        #print "returning\n";
        return;
    }

    push(@current_path, $item);

    if(List::Util::first { $item eq $_ } @start_nodes)
    {
        #print "Matched \"$item\" as a major node.\n";
        push(@path_list, [@current_path]);
    }

    #print "Will travel from \"$item\" to: (", join(',', keys %{$gakker->{$item}}), ")\n";
    foreach my $next (keys %{$gakker->{$item}})
    {
        #print "Going to \"$next\"\n";
        walkit($next, $gakker);
    }

    #print "Restoring (", join(',', @current_path), ') to (', join(',', @saved_path), ")\n";
    @current_path = (@saved_path);
}

sub add_edge
{
    my $from = shift;
    my $type = shift;
    my $to = shift;
    my $weight = shift;

    $a->{$from}->{$type}->{LINK} = 1;
    $a->{$from}->{$type}->{WEIGHT} = $weight;
    $a->{$type}->{$to}->{LINK} = 1;
    $a->{$type}->{$to}->{WEIGHT} = $weight;

}

sub get_paths
{
    my $pl = shift;
    my $num_paths;
    my $path_index;
    my $path_weight;
    my @list;

    foreach my $list (@{$pl})
    {
        my %path_info;
        #print "Inspecting (", join(',', @{$list}), "); length is: ", scalar(@{$list}), "\n";
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
            $path_weight += $a->{$start}->{$type}->{WEIGHT};
            $path_weight += $a->{$type}->{$end}->{WEIGHT};
            #print "Got: ($start, $type, $end)\n";
            $path_index += 2;
        }

        $path_info{WEIGHT} = $path_weight;
        push(@{$extracted_paths->{$path_info{START} . '.' . $path_info{END}}}, \%path_info);
    }
}
