package Idval::Graph::Test;
use strict;
use warnings;
use lib qw{t/lib};

use base qw(Test::Class);
use Test::More;

use Data::Dumper;

use Idval::Graph;

INIT { Test::Class->runtests } # here's the magic!

sub begin : Test(startup) {
    return;
}

sub end : Test(shutdown) {
    return;
}

sub before : Test(setup) {
    # provide fixture
    return;
}

sub after : Test(teardown) {
    # clean up after test
    return;
}

sub init : Test(1)
{
    my $graph = Idval::Graph->new();

    isa_ok($graph, 'Idval::Graph');

    return;
}

# Find the lowest-weighted path between A and W
sub get_lowest_weighted_path_1 : Test(1)
{
    my $graph = Idval::Graph->new();

    $graph->add_edge('A', 'foo', 'B', 100);
    $graph->add_edge('A', 'boo', 'B', 50);
    $graph->add_edge('B', 'goo', 'W', 100);
    $graph->add_edge('W', 'hoo', 'M', 100);

    my $result = $graph->get_best_path('A', 'W');
    is_deeply($result, [['A','boo','B'],['B','goo','W']]);

    return;
}

# Find the lowest-weighted path between A and W
sub get_lowest_weighted_path_1a : Test(1)
{
    my $self = shift;

    my $graph = Idval::Graph->new();

    $graph->add_edge('A', 'foo::hoo', 'B', 100);
    $graph->add_edge('A', 'boo::hoo', 'B', 50);
    $graph->add_edge('B', 'goo::hoo', 'W', 100);
    $graph->add_edge('W', 'hoo::hoo', 'M', 100);

    my $result = $graph->get_best_path('A', 'W');
    is_deeply($result, [['A','boo::hoo','B'],['B','goo::hoo','W']]);

    return;
}

# Find the lowest-weighted path between AXX and WXX
sub get_lowest_weighted_path_1b : Test(1)
{
    my $self = shift;

    my $graph = Idval::Graph->new();

    $graph->add_edge('AXX', 'foo::hoo', 'BXX', 100);
    $graph->add_edge('AXX', 'boo::hoo', 'BXX', 50);
    $graph->add_edge('BXX', 'goo::hoo', 'WXX', 100);
    $graph->add_edge('WXX', 'hoo::hoo', 'MXX', 100);

    my $result = $graph->get_best_path('AXX', 'WXX');
    is_deeply($result, [['AXX','boo::hoo','BXX'],['BXX','goo::hoo','WXX']]);

    return;
}

sub get_lowest_weighted_path_1c : Test(1)
{
    my $self = shift;

    my $graph = Idval::Graph->new();

    $graph->add_edge('AXX', 'foo::hoo', 'BXX', 100);
    $graph->add_edge('BXX', 'goo::hoo', 'WXX', 100);

    my $result = $graph->get_best_path('AXX', 'WXX');
    is_deeply($result, [['AXX','foo::hoo','BXX'],['BXX','goo::hoo','WXX']]);

    return;
}

sub graph_flac_to_ogg : Test(1)
{
    my $graph = Idval::Graph->new();

    $graph->add_edge('WAV', 'Idval::UserPlugins::Garfinkle::flacker', 'FLAC', 100);
    $graph->add_edge('FLAC', 'Idval::UserPlugins::Simon::whacker', 'OGG', 100);

    my $result = $graph->get_best_path('WAV', 'OGG');
    is_deeply($result, [['WAV','Idval::UserPlugins::Garfinkle::flacker','FLAC'],
                        ['FLAC','Idval::UserPlugins::Simon::whacker','OGG']]);

    return;
}

sub get_bogus_requested_path : Test(1)
{
    my $graph = Idval::Graph->new();

    $graph->add_edge('A', 'foo', 'B', 100);
    $graph->add_edge('A', 'boo', 'B', 50);
    $graph->add_edge('B', 'goo', 'W', 100);
    $graph->add_edge('W', 'hoo', 'M', 100);

    my $result = $graph->get_best_path('A', 'Q');
    ok(not $result);

    return;
}

# We should be able to get a loop
sub get_loop : Test(1)
{
    my $graph = Idval::Graph->new();

    $graph->add_edge('A', 'gak', 'A', 100);
    $graph->add_edge('A', 'foo', 'B', 100);
    $graph->add_edge('A', 'boo', 'B', 50);
    $graph->add_edge('B', 'goo', 'W', 100);
    $graph->add_edge('W', 'hoo', 'M', 100);

    my $result = $graph->get_best_path('A', 'A');
    is_deeply($result, [['A','gak','A']]);

    return;
}

sub get_low_weighted_loop : Test(1)
{
    my $graph = Idval::Graph->new();

    $graph->add_edge('A', 'foo', 'B', 100, 'transcode');
    $graph->add_edge('B', 'goo', 'W', 100, 'transcode');
    $graph->add_edge('B', 'hoo', 'A', 200, 'transcode');
    $graph->add_edge('A', 'copy', 'A', 200);
    $graph->add_edge('A', 'big-moo', 'A', 250, 'transcode');

    my $result = $graph->get_best_path('A', 'A');
    is_deeply($result, [['A','copy','A']]);

    return;
}

sub get_low_weighted_transcode_loop : Test(1)
{
    my $graph = Idval::Graph->new();

    $graph->add_edge('A', 'foo', 'B', 100, 'transcode');
    $graph->add_edge('B', 'goo', 'W', 100, 'transcode');
    $graph->add_edge('B', 'hoo', 'A', 200, 'transcode');
    $graph->add_edge('A', 'copy', 'A', 200);
    $graph->add_edge('A', 'big-moo', 'A', 250, 'transcode');

    my $result = $graph->get_best_path('A', 'A', 'transcode');
    is_deeply($result, [['A','big-moo','A']]);

    return;
}

1;
