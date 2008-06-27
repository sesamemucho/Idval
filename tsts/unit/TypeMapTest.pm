package TypeMapTest;
use strict;
use warnings;

use base qw(Test::Unit::TestCase);

use Benchmark qw(:all);
use Data::Dumper;
use File::Glob ':glob';
use FindBin;

use TestUtils;
use Idval::TypeMap;

#our $testdir = "$FindBin::Bin/../tsts/unittest-data";
#my $testdir = "tsts/unittest-data";

sub new {
    my $self = shift()->SUPER::new(@_);
    # your state for fixture here
    $self->{NEWFILES} = [];
    return $self;
}

sub set_up {
    # provide fixture
}

sub tear_down {
    my $self = shift;
    # clean up after test
    unlink(@{$self->{NEWFILES}});

    return;
}

sub test_init1
{
    my $self = shift;
    my $prov = TestUtils::FakeProvider->new();
    my $bm = Idval::TypeMap->new($prov, '%%');

    $self->assert_equals(ref($bm), "Idval::TypeMap");

    return;
}

sub test_get_map1
{
    my $self = shift;
    my $prov = TestUtils::FakeProvider->new();
    my $bm = Idval::TypeMap->new($prov, '%%');

    $self->assert_deep_equals([qw(MUSIC)], [$bm->get_all_classes()]);
    $self->assert_deep_equals([qw(FLAC MP3 OGG)], [$bm->get_all_filetypes()]);
    $self->assert_deep_equals([qw(flac flac16)], [$bm->get_exts_from_filetype('FLAC')]);
    $self->assert_deep_equals([qw(flac flac16 mp3 ogg)], [$bm->get_exts_from_class('MUSIC')]);
    $self->assert_deep_equals([qw(MUSIC FLAC)], [$bm->get_class_and_type_from_ext('flac16')]);
    $self->assert_equals('MUSIC', $bm->get_class_from_filetype('FLAC'));
    $self->assert_equals('OGG', $bm->get_filetype_from_file('foo/goo/boo/coo.ogg'));

    return;
}

1;
