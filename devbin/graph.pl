#!/usr/bin/perl

use strict;
use warnings;
#$Devel::Trace::TRACE = 0;   # Disable
use Getopt::Long;
use Data::Dumper;
use FindBin;
use lib ("$FindBin::Bin/../lib");

use Idval::NGraph;


my $graph = Idval::NGraph->new();

$graph->add_edge('A', 'foo', 'B', 100);
$graph->add_edge('A', 'boo', 'B', 50);
$graph->add_edge('B', 'goo', 'W', 100);
$graph->add_edge('W', 'hoo', 'B', 100);
$graph->add_edge('W', 'hoo', 'M', 100);

print "Starting out: ", Dumper($graph);

$graph->process_graph();

print Dumper($graph);
