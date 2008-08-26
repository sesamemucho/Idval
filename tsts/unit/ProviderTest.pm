package ProviderTest;
use strict;
use warnings;

use base qw(Test::Unit::TestCase);

use Benchmark qw(:all);
use Data::Dumper;
use File::Glob ':glob';
use FindBin;

use TestUtils;
use Idval::Constants;
use Idval::Providers;
use Idval::Common;
use Idval::Config;
use Idval::ServiceLocator;

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
    my $tree1 = {'testdir' => {}};
    Idval::FileString::idv_set_tree($tree1);

    return;
}

sub tear_down {
    # clean up after test
    Idval::FileString::idv_clear_tree();
    TestUtils::unload_packages($provs);

    return;
}

sub test_init
{
    my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt', "\nplugin_dir = /testdir/Idval\n\n");
    add_UserPlugin3_up1();
    my $fc = Idval::Config->new("/testdir/gt1.txt");
    $provs = eval{Idval::Providers->new($fc)};
    $self->assert_equals('Idval::Providers', ref $provs);
    $self->assert_equals(1, $provs->num_providers());

    return;
}

sub test_get_providers
{
    my $self = shift;

    Idval::FileString::idv_add_file('/testdir/gt1.txt', "\nplugin_dir = /testdir/Idval\n\n");
    add_UserPlugin3_up1();
    add_UserPlugin3_up2();
    add_UserPlugin3_up3();
    add_UserPlugin3_up4();
    my $fc = Idval::Config->new("/testdir/gt1.txt");
    $provs = eval{Idval::Providers->new($fc)};
    print "Error from Idval::Providers->new: $@\n" if $@;
    #print "test_get_providers: provs is: ", Dumper($provs);
    $self->assert_equals(4, $provs->num_providers());

    return;
}

sub test_get_packages
{
    my $self = shift;

    Idval::FileString::idv_add_file('/testdir/gt1.txt', "\nplugin_dir = /testdir/Idval\n\n");
    add_UserPlugin3_up1();
    add_UserPlugin3_up2();
    add_UserPlugin3_up3();
    add_UserPlugin3_up4();
    my $fc = Idval::Config->new("/testdir/gt1.txt");
    $provs = Idval::Providers->new($fc);
    $self->assert_equals(4, $provs->num_providers());
    $self->assert_deep_equals(['Idval::UserPlugins::Up1',
                               'Idval::UserPlugins::Up2',
                               'Idval::UserPlugins::Up3',
                               'Idval::UserPlugins::Up4'], $provs->get_packages());

    return;
}

sub test_get_a_provider_1
{
    my $self = shift;

    Idval::FileString::idv_add_file('/testdir/gt1.txt', "\nplugin_dir = /testdir/Idval\n\n");
    add_UserPlugin3_up1();
    add_UserPlugin3_up2();
    add_UserPlugin3_up3();
    add_UserPlugin3_up4();
    my $fc = Idval::Config->new("/testdir/gt1.txt");
    $provs = Idval::Providers->new($fc);
    my $writer = $provs->get_provider('writes_tags', 'OGG');

    $self->assert_equals('Idval::UserPlugins::Up2', ref $writer);

    return;
}

sub test_get_a_provider_2
{
    my $self = shift;
    my $item;

    #my $old_level = Idval::Common::get_logger()->accessor('LOGLEVEL', $CHATTY);
    #my $old_debug = Idval::Common::get_logger()->accessor('DEBUGMASK', $DBG_GRAPH + $DBG_PROVIDERS);
    Idval::FileString::idv_add_file('/testdir/gt1.txt', "\nplugin_dir = /testdir/Idval\n\n");
    add_UserPlugin3_up1();
    add_UserPlugin3_up2();
    add_UserPlugin3_up3();
    add_UserPlugin3_up4();
    my $fc = Idval::Config->new("/testdir/gt1.txt");
    $provs = Idval::Providers->new($fc);
    $item = $provs->get_provider('converts', 'FLAC', 'WAV');
    #Idval::Common::get_logger()->accessor('DEBUGMASK', $old_debug);
    #Idval::Common::get_logger()->accessor('LOGLEVEL', $old_level);
    $self->assert_null($item);

    return;
}

sub test_choose_provider_by_weight_in_config_file_1
{
    my $self = shift;

    Idval::FileString::idv_add_file('/testdir/gt1.txt', "\nplugin_dir = /testdir/Idval\n" .
        "{\ncommand_name = goober\nweight = 50\n}\n");
    add_UserPlugin3_up1();
    add_UserPlugin3_up2();
    add_UserPlugin3_up3();
    add_UserPlugin3_up4();
    my $fc = Idval::Config->new("/testdir/gt1.txt");
    $provs = Idval::Providers->new($fc);
    my $writer = $provs->get_provider('writes_tags', 'MP3');

    $self->assert_equals('Idval::UserPlugins::Up1', ref $writer);

    return;
}

sub test_choose_provider_by_weight_in_config_file_2
{
    my $self = shift;

    Idval::FileString::idv_add_file('/testdir/gt1.txt', "\nplugin_dir = /testdir/Idval\n" .
        "{\ncommand_name == tag_write4\nweight = 50\n}\n");
    add_UserPlugin3_up1();
    add_UserPlugin3_up2();
    add_UserPlugin3_up3();
    add_UserPlugin3_up4();
    my $fc = Idval::Config->new("/testdir/gt1.txt");
    #$Idval::Config::BlockReader::cfg_dbg = 1;
    $provs = Idval::Providers->new($fc);
    #print STDERR Dumper($provs);
    my $writer = $provs->get_provider('writes_tags', 'MP3');
    #$Idval::Config::BlockReader::cfg_dbg = 0;

    $self->assert_equals('Idval::UserPlugins::Up4', ref $writer);

    return;
}

# sub test_get_a_provider_3
# {
#     my $self = shift;

#     my $fc = FakeConfig->new("$testdir/Idval/UserPlugins3");
#     $provs = Idval::Providers->new($fc);

#     my $item = $prov->get_provider('converts', 'WAV', 'FLAC');

#     $self->assert_equals('Idval::UserPlugins::Garfinkle', ref $item);
# }

sub test_get_a_command_1
{
    my $self = shift;

    Idval::FileString::idv_add_file('/testdir/gt1.txt', "\ncommand_dir = /testdir/Idval\n\n");
    add_command_1();
    my $fc = Idval::Config->new("/testdir/gt1.txt");
    $provs = Idval::Providers->new($fc);
    my $cmd = $provs->find_command('cmd1');

    $self->assert_equals('Idval::UserPlugins::Cmd1::cmd1', $cmd);

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

our $name = 'goober';
Idval::Common::register_provider({provides=>'writes_tags', name=>$name, type=>'MP3'});

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
    $self->set_param('filetype_map', {'MP3' => [qw{ mp3 }]});
    $self->set_param('classtype_map', {'MUSIC' => [qw( MP3 )]});
    $self->set_param('is_ok', 1);
}

1;
EOF

    Idval::FileString::idv_add_file('/testdir/Idval/up1.pm', $plugin);

    return;
}

sub add_UserPlugin3_up2
{
    my $plugin =<<'EOF';
package Idval::UserPlugins::Up2;
use Idval::Common;
use base qw(Idval::Plugin);
no warnings qw(redefine);

our $name = 'tag_write2';
Idval::Common::register_provider({provides=>'writes_tags', name=>$name, type=>'OGG'});

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
    $self->set_param('filetype_map', {'OGG' => [qw{ ogg }]});
    $self->set_param('classtype_map', {'MUSIC' => [qw( OGG )]});
    $self->set_param('is_ok', 1);
}

1;
EOF

    Idval::FileString::idv_add_file('/testdir/Idval/up2.pm', $plugin);

    return;
}

sub add_UserPlugin3_up3
{
    my $plugin =<<'EOF';
package Idval::UserPlugins::Up3;
use Idval::Common;
use base qw(Idval::Plugin);
no warnings qw(redefine);

our $name = 'tag_write3';
Idval::Common::register_provider({provides=>'writes_tags', name=>$name, type=>'FLAC'});

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
    $self->set_param('filetype_map', {'FLAC' => [qw{ flac }]});
    $self->set_param('classtype_map', {'MUSIC' => [qw( FLAC )]});
    $self->set_param('is_ok', 1);
}

1;
EOF

    Idval::FileString::idv_add_file('/testdir/Idval/up3.pm', $plugin);

    return;
}

sub add_UserPlugin3_up4
{
    my $plugin =<<'EOF';
package Idval::UserPlugins::Up4;
use Idval::Common;
use base qw(Idval::Plugin);
no warnings qw(redefine);

our $name = 'tag_write4';
Idval::Common::register_provider({provides=>'writes_tags', name=>$name, type=>'MP3'});

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
    $self->set_param('filetype_map', {'MP3' => [qw{ mp3 }]});
    $self->set_param('classtype_map', {'MUSIC' => [qw( MP3 )]});
    $self->set_param('is_ok', 4);
}

1;
EOF

    Idval::FileString::idv_add_file('/testdir/Idval/up4.pm', $plugin);

    return;
}

sub add_command_1
{
    my $plugin =<<'EOF';
package Idval::UserPlugins::Cmd1;
use Idval::Common;

sub init
{
}

sub cmd1
{
    my $datastore = shift;
    my $providers = shift;
    my @args = @_;

    return 0;
}


1;
EOF

    Idval::FileString::idv_add_file('/testdir/Idval/cmd1.pm', $plugin);

    return;
}

1;
