#!/usr/bin/perl

use strict;
use warnings;
#$Devel::Trace::TRACE = 0;   # Disable
use Getopt::Long;
use Data::Dumper;
use FindBin;
use lib ("$FindBin::Bin/../lib");

use Idval::Graph;

my $scenario = 5;

my $graph = Idval::Graph->new();

if ($scenario == 1)
{
    # Basic
    $graph->add_edge('A', 'foo', 'B', 100);
    $graph->add_edge('A', 'boo', 'B', 50);
    $graph->add_edge('B', 'goo', 'W', 100);
    $graph->add_edge('W', 'hoo', 'B', 100);
    $graph->add_edge('W', 'hoo', 'M', 100);
}

if ($scenario == 2)
{
    # 2 ways to get from A to W
    $graph->add_edge('A', 'foo', 'B', 100);
    $graph->add_edge('A', 'foo', 'C', 120);
    #$graph->add_edge('A', 'boo', 'B', 50);
    $graph->add_edge('B', 'goo', 'W', 100);
    $graph->add_edge('C', 'hoo', 'W', 80);
}

if ($scenario == 3)
{
    # Try to get "Total number of valid paths" > "Number of extracted (lowest-weight) paths"
    $graph->add_edge('A', 'foo', 'B', 100);
    $graph->add_edge('B', 'goo', 'W', 100);
    $graph->add_edge('A', 'foo', 'C', 200);
    $graph->add_edge('C', 'hoo', 'W', 200);
}

if ($scenario == 4)
{
    # Fool with A->action->A
    $graph->add_edge('A', 'foo', 'B', 100);
    $graph->add_edge('B', 'goo', 'W', 100);
    $graph->add_edge('B', 'hoo', 'A', 200);
    $graph->add_edge('A', 'moo', 'A', 200);
}

if ($scenario == 5)
{
    # Debug ProviderTest problem
    $graph->add_edge('MP3', 'Idval::UserPlugins::Up4::tag_write4', 'NULL', 100);
    $graph->add_edge('FLAC', 'Idval::UserPlugins::Up3::tag_write3', 'NULL', 100);
    $graph->add_edge('OGG', 'Idval::UserPlugins::Up2::tag_write2', 'NULL', 100);
    $graph->add_edge('MP3', 'Idval::UserPlugins::Up1::goober', 'NULL', 100);
}

print "Starting out: ", Dumper($graph);

$graph->process_graph();

print Dumper($graph);

print "Total number of valid paths: ", scalar(@{$graph->{PATH_LIST}}), "\n";
print "Number of extracted (lowest-weight) paths: ", scalar(keys %{$graph->{EXTRACTED_PATHS}}), "\n";
