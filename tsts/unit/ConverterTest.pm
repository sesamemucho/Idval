package ConverterTest;
use strict;
use warnings;

use base qw(Test::Unit::TestCase);

use Benchmark qw(:all);
use Data::Dumper;
use File::Glob ':glob';
use FindBin;
use Symbol;

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

    Idval::FileString::idv_add_file('/testdir/gt1.txt', "\nplugin_dir = /testdir/Idval\n\n");
    add_UserPlugin3_up1();

    my $fc = eval {Idval::Config->new("/testdir/gt1.txt")};
    $provs = eval{Idval::Providers->new($fc)};
    my $conv = $provs->get_converter('WAV', 'FLAC');

    $self->assert_equals('flacker', $conv->query('name'));

    return;
}

# sub test_get_converter_1
# {
#     my $self = shift;

#     my $fc = FakeConfig->new("$testdir/Idval/UserPlugins3");
#     my $prov = Idval::Providers->new($fc);

#     my $conv = $prov->get_converter('FLAC', 'OGG');

#     $self->assert_equals('whacker', $conv->query('name'));
# }


# # Two converters get Smooshed together
# sub test_get_WavetoOGGconverter
# {
#     my $self = shift;

#     my $fc = FakeConfig->new("$testdir/Idval/UserPlugins3");
#     my $prov = Idval::Providers->new($fc);

#     my $conv = $prov->get_converter('WAV', 'OGG');

#     $self->assert_equals('flacker/whacker', $conv->query('name'));
# }

##-------------------------------------------------##

sub add_UserPlugin3_up1
{
    my $plugin =<<'EOF';
package Idval::UserPlugins::Up1;
use Idval::Setup;
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
