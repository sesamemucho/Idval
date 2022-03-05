package Idval::Provider::Test;
use strict;
use warnings;
use lib qw{t/lib};

use base qw(Test::Class);
use Test::More;

use Data::Dumper;

use TestUtils;
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
    TestUtils::add_Provider({provides=>'writes_tags',
                             name=>'mp3tagger',
                             type=>'MP3'});

    my $fc = TestUtils::setup_Config();
    $provs = eval{Idval::ProviderMgr->new($fc)};
    isa_ok($provs, 'Idval::ProviderMgr');
    is($provs->num_providers(), 1);

    return;
}

sub get_providers : Test(1)
{
    TestUtils::add_Provider({provides=>'writes_tags',
                             name=>'mp3tagger',
                             type=>'MP3'});
    TestUtils::add_Provider({provides=>'writes_tags',
                             name=>'goober',
                             type=>'MP3',
                             weight=>300});
    TestUtils::add_Provider({provides=>'writes_tags',
                             name=>'oggtagger',
                             type=>'OGG'});
    TestUtils::add_Provider({provides=>'writes_tags',
                             name=>'flacber',
                             type=>'FLAC'});

    my $fc = TestUtils::setup_Config();
    $provs = eval{Idval::ProviderMgr->new($fc)};
    print STDERR "Error from Idval::ProviderMgr->new: $@\n" if $@;
    #print "test_get_providers: provs is: ", Dumper($provs);
    is($provs->num_providers(), 4);

    return;
}

sub get_a_provider_1 : Test(1)
{
    TestUtils::add_Provider({provides=>'writes_tags',
                             name=>'mp3tagger',
                             type=>'MP3'});
    TestUtils::add_Provider({provides=>'writes_tags',
                             name=>'goober',
                             type=>'MP3',
                             weight=>300});
    TestUtils::add_Provider({provides=>'writes_tags',
                             name=>'oggtagger',
                             type=>'OGG'});
    TestUtils::add_Provider({provides=>'writes_tags',
                             name=>'flacber',
                             type=>'FLAC'});

    my $fc = TestUtils::setup_Config();
    $provs = Idval::ProviderMgr->new($fc);
    my $writer = $provs->get_provider('writes_tags', 'OGG', 'NULL');

    is(ref $writer, 'Idval::Plugins::oggtagger');

    return;
}

sub get_a_provider_2 : Test(1)
{
    TestUtils::add_Provider({provides=>'writes_tags',
                             name=>'mp3tagger',
                             type=>'MP3'});
    TestUtils::add_Provider({provides=>'writes_tags',
                             name=>'goober',
                             type=>'MP3',
                             weight=>300});
    TestUtils::add_Provider({provides=>'writes_tags',
                             name=>'oggtagger',
                             type=>'OGG'});
    TestUtils::add_Provider({provides=>'writes_tags',
                             name=>'flacber',
                             type=>'FLAC'});

    my $fc = TestUtils::setup_Config();
    $provs = Idval::ProviderMgr->new($fc);
    # Test will print an error message if run_test... is not used
    my ($item, $result) = TestUtils::run_test_and_get_log($provs, 'get_provider', 'converts', 'FLAC', 'WAV');
    #like($result, qr/No "converts" provider found for "FLAC,WAV"/);
    ok(not $item);

    return;
}

sub get_provider_default_is_lesser_weight : Test(1)
{
    my $item;

    TestUtils::add_Provider({provides=>'writes_tags',
                             name=>'mp3tagger',
                             type=>'MP3'});
    TestUtils::add_Provider({provides=>'writes_tags',
                             name=>'goober',
                             type=>'MP3',
                             weight=>300});
    TestUtils::add_Provider({provides=>'writes_tags',
                             name=>'oggtagger',
                             type=>'OGG'});
    TestUtils::add_Provider({provides=>'writes_tags',
                             name=>'flacber',
                             type=>'FLAC'});

    my $fc = TestUtils::setup_Config();
    $provs = Idval::ProviderMgr->new($fc);
    $item = $provs->get_provider('writes_tags', 'MP3', 'NULL');
    is(ref $item, 'Idval::Plugins::mp3tagger');

    return;
}

sub choose_provider_by_weight_in_config_file_1 : Test(1)
{
    TestUtils::add_Provider({provides=>'writes_tags',
                             name=>'mp3tagger',
                             type=>'MP3'});
    TestUtils::add_Provider({provides=>'writes_tags',
                             name=>'goober',
                             type=>'MP3',
                             weight=>300});
    TestUtils::add_Provider({provides=>'writes_tags',
                             name=>'oggtagger',
                             type=>'OGG'});
    TestUtils::add_Provider({provides=>'writes_tags',
                             name=>'flacber',
                             type=>'FLAC'});

    my $fc = TestUtils::setup_Config("{\ncommand_name == goober\nweight = 50\n}\n");

    $provs = Idval::ProviderMgr->new($fc);
    my $writer = $provs->get_provider('writes_tags', 'MP3', 'NULL');

    is(ref $writer, 'Idval::Plugins::goober');

    return;
}

sub get_a_command_1 : Test(2)
{
    Idval::FileString::idv_add_file('/testdir/gt1.txt', "\ncommand_dir = /testdir/Idval\n\n");
    add_command_1();
    my $fc = Idval::Config->new("/testdir/gt1.txt");
    $provs = Idval::ProviderMgr->new($fc);
    my @cmds = $provs->_get_providers({types => ['command']});

    is(scalar(@cmds), 1);

    #is($cmd, 'Idval::Plugins::Cmd1::cmd1');
    isa_ok($cmds[0], 'Idval::Command');

    return;
}

sub test_smooshing_a_smoosh : Test(3)
{
    my $self = shift;

    TestUtils::add_Provider({provides=>'converts',
                             name=>'copy',
                             from=>'*',
                             to=>'*'});
    TestUtils::add_Provider({provides=>'converts',
                             name=>'ogger',
                             from=>'OGG',
                             to=>'WAV'});
    TestUtils::add_Provider({provides=>'converts',
                             name=>'flacker',
                             from=>'WAV',
                             to=>'FLAC'});
    TestUtils::add_Provider({provides=>'filters',
                             name=>'gakker',
                             from=>'WAV',
                             to=>'WAV',
                             attributes=>['filter']});
    TestUtils::add_Provider({provides=>'filters',
                             name=>'oggfilter',
                             from=>'OGG',
                             to=>'OGG',
                             attributes=>['filter']});

    my $fc = TestUtils::setup_Config();
    #my $save_logger = Idval::Logger::get_logger();
    #Idval::Logger::re_init({debugmask=>'Converter:4'});
    #$save_logger->set_debugmask('+Smoosh:4,+ProviderMgr:4');
    #$save_logger->str('CT');
    $provs = Idval::ProviderMgr->new($fc);
    my $conv = $provs->get_provider('converts', 'OGG', 'WAV', 'filter:gakker');

    is($conv->query('name'), 'ogger/gakker');

    # gakker filters WAV/WAV, so it will go after ogger
    $conv = $provs->get_provider('converts', 'OGG', 'FLAC', 'filter:gakker');
    is($conv->query('name'), 'ogger/gakker/flacker');

    # oggfilter filters OGG/OGG, so it will go before ogger
    $conv = $provs->get_provider('converts', 'OGG', 'FLAC', 'filter:gakker', 'filter:oggfilter');
    is($conv->query('name'), 'oggfilter/ogger/gakker/flacker');

    return;
}

sub test_smooshing_a_smoosh_must_all_be_filters : Test(2)
{
    my $self = shift;

    TestUtils::add_Provider({provides=>'converts',
                             name=>'copy',
                             from=>'*',
                             to=>'*'});
    TestUtils::add_Provider({provides=>'converts',
                             name=>'ogger',
                             from=>'OGG',
                             to=>'WAV'});
    TestUtils::add_Provider({provides=>'converts',
                             name=>'flacker',
                             from=>'WAV',
                             to=>'FLAC'});
    TestUtils::add_Provider({provides=>'filters',
                             name=>'gakker',
                             from=>'WAV',
                             to=>'WAV',
                             attributes=>['filter']});
    TestUtils::add_Provider({provides=>'filters',
                             name=>'oggfilter',
                             from=>'OGG',
                             to=>'OGG',
                             attributes=>['filter']});

    my $fc = TestUtils::setup_Config();
    #my $save_logger = Idval::Logger::get_logger();
    #Idval::Logger::re_init({debugmask=>'Converter:4'});
    #$save_logger->set_debugmask('+Smoosh:4,+ProviderMgr:4');
    #$save_logger->str('CT');
    $provs = Idval::ProviderMgr->new($fc);

    my $result = TestUtils::run_test_and_get_log($provs, 'get_provider', 'converts', 'OGG', 'WAV', 'filter:flacker');
    like($result, qr/1 filter was not found/);

    $result = TestUtils::run_test_and_get_log($provs, 'get_provider', 'converts', 'OGG', 'WAV', 'filter:flacker', 'filter:pilter');
    like($result, qr/2 filters were not found/);

    return;
}

##-------------------------------------------------##

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
