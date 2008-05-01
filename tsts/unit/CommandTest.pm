package CommandTest;
use base qw(Test::Unit::TestCase);

use Benchmark qw(:all);
use Data::Dumper;
use File::Glob ':glob';
use FindBin;

use TestUtils;
use Idval::Config;
use Idval::Providers;
use Idval::ServiceLocator;

our $tree1 = {'testdir' => {}};
our $testdir = "tsts/unittest-data";
our $provs;

sub new {
    my $self = shift()->SUPER::new(@_);
    # your state for fixture here
    Idval::ServiceLocator::provide('io_type', 'FileString');
    return $self;
}

sub set_up {
    # provide fixture
    Idval::FileString::idv_set_tree($tree1);
}

sub tear_down {
    # clean up after test
    Idval::FileString::idv_clear_tree();
    TestUtils::unload_packages($provs);
}

sub test_get_converter
{
    my $self = shift;

    Idval::FileString::idv_add_file('/testdir/gt1.txt', "\nplugin_dir = /testdir/Idval\n\n");
    add_UserPlugin3_up1();

    my $fc = Idval::Config->new("/testdir/gt1.txt");
    $provs = Idval::Providers->new($fc);
    my $conv = $provs->get_command('goober');

    $self->assert($conv);
}

##-------------------------------------------------##

sub add_UserPlugin3_up1
{
    my $plugin =<<'EOF';
package Idval::UserPlugins::Up1;
use Idval::Setup;
use Idval::Common;
use base qw(Idval::Plugin);
no warnings qw(redefine);

Idval::Common::register_provider({provides=>'command', name=>'goober'});

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    bless($self, ref($class) || $class);
    $self->_init(@_);
    return $self;
}

sub _init
{
    my $self = shift;

    $self->set_param('name', $self->{NAME});
    $self->set_param('is_ok', 1);
    $self->set_param('short_status', 'OK');
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
}

1;
