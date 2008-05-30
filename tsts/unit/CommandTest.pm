package CommandTest;

use strict;
use warnings;

use base qw(Test::Unit::TestCase);

use Benchmark qw(:all);
use Data::Dumper;
use File::Glob ':glob';
use FindBin;

use TestUtils;
use Idval::Config;
use Idval::Providers;
use Idval::ServiceLocator;

my $tree1 = {'testdir' => {}};
my $testdir = "tsts/unittest-data";
my $provs;

sub new {
    my $self = shift()->SUPER::new(@_);
    # your state for fixture here
    Idval::ServiceLocator::provide('io_type', 'FileString');
    return $self;
}

sub set_up {
    # provide fixture
    Idval::FileString::idv_set_tree($tree1);

    return;
}

sub tear_down {
    # clean up after test
    Idval::FileString::idv_clear_tree();
    TestUtils::unload_packages($provs);

    return;
}

sub test_get_converter
{
    my $self = shift;

    print STDERR "Hello from test_get_converter\n";
    Idval::FileString::idv_add_file('/testdir/gt1.txt', "\nplugin_dir = /testdir/Idval\n\n");
    print STDERR "Hello 1 from test_get_converter\n";
    add_UserPlugin3_up1();
    print STDERR "Hello 2 from test_get_converter\n";

    my $fc = Idval::Config->new("/testdir/gt1.txt");
    print STDERR "Hello 3 from test_get_converter\n";
    $provs = Idval::Providers->new($fc);
    #print STDERR "provs is:", Dumper($provs);
    my $conv = $provs->_get_command('goober', '/testdir/Idval/up1.pm');

    $self->assert($conv);

    return;
}

##-------------------------------------------------##

sub add_UserPlugin3_up1
{
    my $plugin =<<'EOF';
package Idval::UserPlugins::Up1;
use Idval::Common;
use base qw(Idval::Plugin);
no warnings qw(redefine);

#Idval::Common::register_provider({provides=>'command', name=>'goober'});

sub init
{

    return;
}

sub goober
{
    my $self = shift;
    my $datastore = shift;

    return $datastore;
}

1;
EOF

    Idval::FileString::idv_add_file('/testdir/Idval/up1.pm', $plugin);

    return;
}

1;
