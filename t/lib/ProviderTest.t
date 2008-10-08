package Idval::Provider::Test;
use strict;
use warnings;
use lib qw{t/lib};

use base qw(Test::Class);
use Test::More;

use Data::Dumper;

use TestUtils;
use Idval::Constants;
use Idval::ProviderMgr;
use Idval::Common;
use Idval::Logger;
use Idval::Config;
use Idval::ServiceLocator;

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

sub init : Test(2)
{
    Idval::FileString::idv_add_file('/testdir/gt1.txt', "\nprovider_dir = /testdir/Idval\n\n");
    add_UserPlugin3_up1();
    my $fc = Idval::Config->new("/testdir/gt1.txt");
    $provs = eval{Idval::ProviderMgr->new($fc)};
    isa_ok($provs, 'Idval::ProviderMgr');
    is($provs->num_providers(), 1);

    return;
}

sub get_providers : Test(1)
{
    #my $self = shift;

    Idval::FileString::idv_add_file('/testdir/gt1.txt', "\nprovider_dir = /testdir/Idval\n\n");
    add_UserPlugin3_up1();
    add_UserPlugin3_up2();
    add_UserPlugin3_up3();
    add_UserPlugin3_up4();
    my $fc = Idval::Config->new("/testdir/gt1.txt");
    $provs = eval{Idval::ProviderMgr->new($fc)};
    print "Error from Idval::ProviderMgr->new: $@\n" if $@;
    #print "test_get_providers: provs is: ", Dumper($provs);
    is($provs->num_providers(), 4);

    return;
}

sub get_packages : Test(2)
{
    #my $self = shift;

    Idval::FileString::idv_add_file('/testdir/gt1.txt', "\nprovider_dir = /testdir/Idval\n\n");
    add_UserPlugin3_up1();
    add_UserPlugin3_up2();
    add_UserPlugin3_up3();
    add_UserPlugin3_up4();
    my $fc = Idval::Config->new("/testdir/gt1.txt");
    $provs = Idval::ProviderMgr->new($fc);
    is($provs->num_providers(), 4);
    is_deeply(['Idval::Plugins::Up1',
               'Idval::Plugins::Up2',
               'Idval::Plugins::Up3',
               'Idval::Plugins::Up4'], $provs->get_packages());

    return;
}

sub get_a_provider_1 : Test(1)
{
    #my $self = shift;

    Idval::FileString::idv_add_file('/testdir/gt1.txt', "\nprovider_dir = /testdir/Idval\n\n");
    add_UserPlugin3_up1();
    add_UserPlugin3_up2();
    add_UserPlugin3_up3();
    add_UserPlugin3_up4();
    my $fc = Idval::Config->new("/testdir/gt1.txt");
    $provs = Idval::ProviderMgr->new($fc);
    my $writer = $provs->get_provider('writes_tags', 'OGG');

    is(ref $writer, 'Idval::Plugins::Up2');

    return;
}

sub get_a_provider_2 : Test(1)
{
    #my $self = shift;
    my $item;

    #my $old_level = Idval::Common::get_logger()->accessor('LOGLEVEL', $CHATTY);
    #my $old_debug = Idval::Common::get_logger()->accessor('DEBUGMASK', $DBG_GRAPH + $DBG_PROVIDERS);
    Idval::FileString::idv_add_file('/testdir/gt1.txt', "\nprovider_dir = /testdir/Idval\n\n");
    add_UserPlugin3_up1();
    add_UserPlugin3_up2();
    add_UserPlugin3_up3();
    add_UserPlugin3_up4();
    my $fc = Idval::Config->new("/testdir/gt1.txt");
    $provs = Idval::ProviderMgr->new($fc);
    $item = $provs->get_provider('converts', 'FLAC', 'WAV');
    #Idval::Common::get_logger()->accessor('DEBUGMASK', $old_debug);
    #Idval::Common::get_logger()->accessor('LOGLEVEL', $old_level);
    ok(not $item);

    return;
}

sub choose_provider_by_weight_in_config_file_1 : Test(1)
{
    my $self = shift;

    Idval::FileString::idv_add_file('/testdir/gt1.txt', "\nprovider_dir = /testdir/Idval\n" .
        "{\ncommand_name == goober\nweight = 50\n}\n");
    add_UserPlugin3_up1();
    add_UserPlugin3_up2();
    add_UserPlugin3_up3();
    add_UserPlugin3_up4();
    my $fc = Idval::Config->new("/testdir/gt1.txt");
    #Idval::Logger::initialize_logger({log_out => 'STDERR'});
    #my $old_level = Idval::Common::get_logger()->accessor('LOGLEVEL', $CHATTY);
    #my $old_debug = Idval::Common::get_logger()->accessor('DEBUGMASK', $DBG_GRAPH + $DBG_PROVIDERS);
    $provs = Idval::ProviderMgr->new($fc);
    my $writer = $provs->get_provider('writes_tags', 'MP3');
    #Idval::Common::get_logger()->accessor('DEBUGMASK', $old_debug);
    #Idval::Common::get_logger()->accessor('LOGLEVEL', $old_level);

    is(ref $writer, 'Idval::Plugins::Up1');

    return;
}

sub choose_provider_by_weight_in_config_file_2 : Test(1)
{
    #my $self = shift;

    Idval::FileString::idv_add_file('/testdir/gt1.txt', "\nprovider_dir = /testdir/Idval\n" .
        "{\ncommand_name == tag_write4\nweight = 50\n}\n");
    add_UserPlugin3_up1();
    add_UserPlugin3_up2();
    add_UserPlugin3_up3();
    add_UserPlugin3_up4();
    my $fc = Idval::Config->new("/testdir/gt1.txt");
    #$Idval::Config::BlockReader::cfg_dbg = 1;
    $provs = Idval::ProviderMgr->new($fc);
    #print STDERR Dumper($provs);
    my $writer = $provs->get_provider('writes_tags', 'MP3');
    #$Idval::Config::BlockReader::cfg_dbg = 0;

    is(ref $writer, 'Idval::Plugins::Up4');

    return;
}

# sub get_a_provider_3 : Test(1)
# {
#     #my $self = shift;

#     my $fc = FakeConfig->new("$testdir/Idval/UserPlugins3");
#     $provs = Idval::ProviderMgr->new($fc);

#     my $item = $prov->get_provider('converts', 'WAV', 'FLAC');

#     is('Idval::Plugins::Garfinkle', ref $item);
# }

sub get_a_command_1 : Test(1)
{
    #my $self = shift;

    Idval::FileString::idv_add_file('/testdir/gt1.txt', "\ncommand_dir = /testdir/Idval\n\n");
    add_command_1();
    my $fc = Idval::Config->new("/testdir/gt1.txt");
    $provs = Idval::ProviderMgr->new($fc);
    my $cmd = $provs->find_command('cmd1');

    #is($cmd, 'Idval::Plugins::Cmd1::cmd1');
    is($cmd, 'Idval::Plugins::Cmd1');

    return;
}

##-------------------------------------------------##

sub add_UserPlugin3_up1
{
    my $plugin =<<'EOF';
package Idval::Plugins::Up1;
use Idval::Common;
use base qw(Idval::Provider);
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
package Idval::Plugins::Up2;
use Idval::Common;
use base qw(Idval::Provider);
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
package Idval::Plugins::Up3;
use Idval::Common;
use base qw(Idval::Provider);
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
package Idval::Plugins::Up4;
use Idval::Common;
use base qw(Idval::Provider);
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
package Idval::Plugins::Cmd1;
use Idval::Common;

sub init
{
}

#sub cmd1
sub main
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
