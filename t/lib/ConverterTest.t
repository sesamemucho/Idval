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

    TestUtils::add_Provider({provides=>'converts',
                             name=>'flacker',
                             from=>'WAV',
                             to=>'FLAC'});

    my $fc = TestUtils::setup_Config();
    $provs = Idval::ProviderMgr->new($fc);
    my $conv = $provs->get_converter('WAV', 'FLAC');

    is($conv->query('name'), 'flacker');
    return;
}

sub test_smoosh : Test(2)
{
    my $self = shift;

    TestUtils::add_Provider({provides=>'converts',
                             name=>'ogger',
                             from=>'OGG',
                             to=>'WAV'});
    TestUtils::add_Provider({provides=>'converts',
                             name=>'flacker',
                             from=>'WAV',
                             to=>'FLAC'});

    my $fc = TestUtils::setup_Config();
    $provs = Idval::ProviderMgr->new($fc);
    my $ogger = $provs->get_converter('OGG', 'WAV');
    my $flacker = $provs->get_converter('WAV', 'FLAC');

    my $conv = Idval::Converter::Smoosh->new(
        'OGG',
        'FLAC',
        $ogger,
        $flacker);

    is($conv->query('name'), 'ogger/flacker');
    return;
}

1;
