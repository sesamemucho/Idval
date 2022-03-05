package Idval::Validate::Test;
use strict;
use warnings;
use lib qw{t/lib};

use base qw(Test::Class);
use Test::More;

use Data::Dumper;
#use Memoize;

use Idval::Validate;
use Idval::FileIO;
use Idval::ServiceLocator;

our $tempfiles;

INIT { Test::Class->runtests } # here's the magic!

sub begin : Test(startup) {
    $tempfiles = [];
    # your state for fixture here
    # Tell the system to use the string-based filesystem services (i.e., the unit-testing version)
    Idval::ServiceLocator::provide('io_type', 'FileString');
    return;
}

sub end : Test(shutdown) {
    unlink @{$tempfiles} if defined($tempfiles);
    return;
}


sub before : Test(setup) {
    # provide fixture
    my $tree1 = {'testdir' => {}};
    Idval::FileString::idv_set_tree($tree1);
    Idval::Common::register_common_object('tempfiles', $tempfiles);

    return;
}

sub after : Test(teardown) {
    # clean up after test
    Idval::FileString::idv_clear_tree();

    return;
}

sub tagname_returned_keyed_by_gripe : Test(1)
{
    my $obj = Idval::Validate->new("{\nYEAR == 2006\nGRIPE = Bad Year!\n}\n");

    my $vars = $obj->merge_blocks({'YEAR' => '2006'});

    is_deeply($vars, {q{Bad Year!} => ['YEAR']});
    return;
}

sub tagname_returned_keyed_by_gripe2 : Test(1)
{
    # There really shouldn't be anything except a GRIPE defined in a validate config file.
    my $obj = Idval::Validate->new("{\nYEAR == 2006\nGRIPE = Bad Year!\nguffer = fuffer\n}\n");

    my $vars = $obj->merge_blocks({'YEAR' => '2006'});

    is_deeply($vars, {q{Bad Year!} => ['YEAR']});
    return;
}

sub tagnames_returned_as_array_ref : Test(1)
{
    my $obj = Idval::Validate->new("{\nYEAR == 2006\nTPE1 == boo hoo\nGRIPE = Bad Year!\n}\n");

    my $vars = $obj->merge_blocks({'YEAR' => '2006', 'TPE1' => 'boo hoo'});

    is_deeply($vars, {q{Bad Year!} => ['YEAR', 'TPE1']});
    return;
}

sub nothing_returned_if_no_match : Test(1)
{
    my $obj = Idval::Validate->new("{\nYEAR == 2006\nTPE1 == boo hoo\nGRIPE = Bad Year!\n}\n");

    my $vars = $obj->merge_blocks({'YEAR' => '2006', 'TPE1' => 'boo'});

    is_deeply($vars, {});
    return;
}

sub regexp_tagnames_1 : Test(1)
{
    my $obj = Idval::Validate->new("{\nT.* has Flac\nGRIPE = Bad Flac!\n}\n");

    my $vars = $obj->merge_blocks({'YEAR' => '2006', 'TPE1' => 'boo Flac', 'TXXX' => 'goo Flac', 'TYYY' => 'foobar'});

    is_deeply($vars, {q{Bad Flac!} => ['TPE1', 'TXXX']});
    return;
}

