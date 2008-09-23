package Idval::TypeMap::Test;
use strict;
use warnings;

use base qw(Test::Class);
use Test::More;

use Data::Dumper;
use FindBin;

use TestUtils;
use Idval::TypeMap;

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

sub test_init1 : Test(1)
{
    my $prov = TestUtils::FakeProvider->new();
    my $bm = Idval::TypeMap->new($prov, '%%');

    isa_ok($bm, "Idval::TypeMap");

    return;
}

sub test_get_map1 : Test(7)
{
    my $prov = TestUtils::FakeProvider->new();
    my $bm = Idval::TypeMap->new($prov, '%%');

    is_deeply([$bm->get_all_classes()], [qw(MUSIC)]);
    is_deeply([$bm->get_all_filetypes()], [qw(FLAC MP3 OGG)]);
    is_deeply([$bm->get_exts_from_filetype('FLAC')], [qw(flac flac16)]);
    is_deeply([$bm->get_exts_from_class('MUSIC')], [qw(flac flac16 mp3 ogg)]);
    is_deeply([$bm->get_class_and_type_from_ext('flac16')], [qw(MUSIC FLAC)]);
    is($bm->get_class_from_filetype('FLAC'), 'MUSIC');
    is($bm->get_filetype_from_file('foo/goo/boo/coo.ogg'), 'OGG');

    return;
}

1;
