package Idval::Converter::Test;
use strict;
use warnings;
use lib qw{t/lib};

use base qw(Test::Class);
use Test::More;

use Data::Dumper;

use TestUtils;
use Idval::Config;
use Idval::ProviderMgr;
use Idval::ServiceLocator;

#my $tree1 = {'testdir' => {}};
#my $testdir = "tsts/unittest-data";
my $provs;

INIT { Test::Class->runtests } # here's the magic!

sub begin : Test(startup) {
    # your state for fixture here
    # Tell the system to use the string-based filesystem services (i.e., the unit-testing version)
    Idval::ServiceLocator::provide('io_type', 'FileString');
    return;
}

sub end : Test(shutdown) {
    return;
}


sub before : Test(setup) {
    # provide fixture
    my $tree1 = {'testdir' => {}};
    Idval::FileString::idv_set_tree($tree1);

    return;
}

sub after : Test(teardown) {
    # clean up after test
    Idval::FileString::idv_clear_tree();
    #TestUtils::unload_packages($provs);

    return;
}

sub get_converter : Test(1)
{
    my $self = shift;

    Idval::FileString::idv_add_file('/testdir/gt1.txt', "\nprovider_dir = /testdir/Idval\n\n");
    add_UserPlugin3_up1();

    my $fc = Idval::Config->new("/testdir/gt1.txt");
    $provs = Idval::ProviderMgr->new($fc);
    my $conv = $provs->get_converter('WAV', 'FLAC');

    is($conv->query('name'), 'flacker');

    return;
}

# sub test_get_converter_1
# {
#     my $self = shift;

#     my $fc = FakeConfig->new("$testdir/Idval/UserPlugins3");
#     my $prov = Idval::ProviderMgr->new($fc);

#     my $conv = $prov->get_converter('FLAC', 'OGG');

#     $self->assert_equals('whacker', $conv->query('name'));
# }


# # Two converters get Smooshed together
# sub test_get_WavetoOGGconverter
# {
#     my $self = shift;

#     my $fc = FakeConfig->new("$testdir/Idval/UserPlugins3");
#     my $prov = Idval::ProviderMgr->new($fc);

#     my $conv = $prov->get_converter('WAV', 'OGG');

#     $self->assert_equals('flacker/whacker', $conv->query('name'));
# }

##-------------------------------------------------##

sub add_UserPlugin3_up1
{
    my $plugin =<<'EOF';
package Idval::Plugins::Up1;
use Idval::Common;
use base qw(Idval::Converter);
no warnings qw(redefine);

our $name = 'flacker';
Idval::Common::register_provider({provides=>'converts', name=>$name, from=>'WAV', to=>'FLAC'});

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

    $self->set_param('name', $name);
    $self->set_param('filetype_map', {'WAV' => [qw{ wav }],
                                      'FLAC' => [qw{ flac flac16 flac24}]});
    $self->set_param('classtype_map', {'MUSIC' => [qw( WAV FLAC )]});
    $self->set_param('is_ok', 1);
    $self->set_param('from', 'WAV');
    $self->set_param('to', 'FLAC');
}

1;
EOF

    Idval::FileString::idv_add_file('/testdir/Idval/up1.pm', $plugin);

    return;
}

1;
