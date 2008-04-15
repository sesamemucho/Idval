package GraphTest;
use base qw(Test::Unit::TestCase);

use Benchmark qw(:all);
use Data::Dumper;
use File::Glob ':glob';
use Symbol;

use Idval::Graph;

sub new {
    my $self = shift()->SUPER::new(@_);
    # your state for fixture here
    return $self;
}

sub set_up {
    # provide fixture
}
sub tear_down {
    # clean up after test
}

sub test_init
{
    my $self = shift;

    my $graph = Idval::Graph->new();

    $self->assert_equals('Idval::Graph', ref $graph);

#     #print STDERR Dumper($graph);

#     $graph->do_walk();
#     $graph->get_paths();

#     print STDERR Dumper($graph);

}

# Find the lowest-weighted path between A and W
sub test_graph1
{
    my $self = shift;

    my $graph = Idval::Graph->new();

    $graph->add_edge('A', 'foo', 'B', 100);
    $graph->add_edge('A', 'boo', 'B', 50);
    $graph->add_edge('B', 'goo', 'W', 100);
    $graph->add_edge('W', 'hoo', 'M', 100);

    my $result = $graph->get_best_path('A', 'W');
    $self->assert_deep_equals([['A','boo','B'],['B','goo','W']], $result);
}

# Find the lowest-weighted path between A and W
sub test_graph1a
{
    my $self = shift;

    my $graph = Idval::Graph->new();

    $graph->add_edge('A', 'foo::hoo', 'B', 100);
    $graph->add_edge('A', 'boo::hoo', 'B', 50);
    $graph->add_edge('B', 'goo::hoo', 'W', 100);
    $graph->add_edge('W', 'hoo::hoo', 'M', 100);

    my $result = $graph->get_best_path('A', 'W');
    $self->assert_deep_equals([['A','boo::hoo','B'],['B','goo::hoo','W']], $result);
}

# Find the lowest-weighted path between AXX and WXX
sub test_graph1b
{
    my $self = shift;

    my $graph = Idval::Graph->new();

    $graph->add_edge('AXX', 'foo::hoo', 'BXX', 100);
    $graph->add_edge('AXX', 'boo::hoo', 'BXX', 50);
    $graph->add_edge('BXX', 'goo::hoo', 'WXX', 100);
    $graph->add_edge('WXX', 'hoo::hoo', 'MXX', 100);

    my $result = $graph->get_best_path('AXX', 'WXX');
    $self->assert_deep_equals([['AXX','boo::hoo','BXX'],['BXX','goo::hoo','WXX']], $result);
}

sub test_graph1c
{
    my $self = shift;

    my $graph = Idval::Graph->new();

    $graph->add_edge('AXX', 'foo::hoo', 'BXX', 100);
    $graph->add_edge('BXX', 'goo::hoo', 'WXX', 100);

    my $result = $graph->get_best_path('AXX', 'WXX');
    $self->assert_deep_equals([['AXX','foo::hoo','BXX'],['BXX','goo::hoo','WXX']], $result);
}

sub test_graph_flac_to_ogg
{
    my $self = shift;

    my $graph = Idval::Graph->new();

    $graph->add_edge('WAV', 'Idval::UserPlugins::Garfinkle::flacker', 'FLAC', 100);
    $graph->add_edge('FLAC', 'Idval::UserPlugins::Simon::whacker', 'OGG', 100);

    my $result = $graph->get_best_path('WAV', 'OGG');
    $self->assert_not_null($result);
    $self->assert_deep_equals([['WAV','Idval::UserPlugins::Garfinkle::flacker','FLAC'],
                               ['FLAC','Idval::UserPlugins::Simon::whacker','OGG']],
                              $result);
}

sub test_graph_bogus_requested_path
{
    my $self = shift;

    my $graph = Idval::Graph->new();

    $graph->add_edge('A', 'foo', 'B', 100);
    $graph->add_edge('A', 'boo', 'B', 50);
    $graph->add_edge('B', 'goo', 'W', 100);
    $graph->add_edge('W', 'hoo', 'M', 100);

    my $result = $graph->get_best_path('A', 'Q');
    $self->assert_null($result);
}

# We should be able to get a loop
sub test_graph2
{
    my $self = shift;

    my $graph = Idval::Graph->new();

    $graph->add_edge('A', 'gak', 'A', 100);
    $graph->add_edge('A', 'foo', 'B', 100);
    $graph->add_edge('A', 'boo', 'B', 50);
    $graph->add_edge('B', 'goo', 'W', 100);
    $graph->add_edge('W', 'hoo', 'M', 100);

    my $result = $graph->get_best_path('A', 'A');
    $self->assert_deep_equals([['A','gak','A']], $result);
}

1;
