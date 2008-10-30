package Idval::Collection::Test;
use strict;
use warnings;
use lib qw{t/lib};

use base qw(Test::Class);
use Test::More;

use Data::Dumper;
use Idval::Collection;
use Idval::Record;

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

sub add_records_to_collection : Test(1)
{
    my $coll = Idval::Collection->new();

    my $rec1 = Idval::Record->new({FILE=>'foo'});
    $rec1->add_tag('GOBBLE', 'hobble');
    my $rec2 = Idval::Record->new({FILE=>'boo'});
    $rec2->add_tag('GOBBLE', 'hobble');

    $coll->add($rec1);
    $coll->add($rec2);

    my @keys = $coll->get_keys();

    is (scalar @keys, 2);
    return;
}

sub purge_records_in_collection : Test(2)
{
    my $coll = Idval::Collection->new();

    my $rec1 = Idval::Record->new({FILE=>'foo'});
    $rec1->add_tag('GOBBLE', 'hobble');
    $rec1->add_tag('CLASS', 'KLASS');
    $rec1->add_tag('TYPE', 'TIPE');
    $rec1->add_tag('__FOO_BOO', 'GOO GOO');
    $rec1->add_tag('FOORAY', ['gobble', 'bobble', 'wobble']);
    my $rec2 = Idval::Record->new({FILE=>'boo'});
    $rec2->add_tag('GOBBLE', 'hobble');
    $rec2->add_tag('CLASS', 'KLASS');
    $rec2->add_tag('TYPE', 'TIPE');
    $rec2->add_tag('__FOO_BOO', 'GOO GOO');
    $rec2->add_tag('FOORAY', ['gobble', 'bobble', 'wobble']);

    $coll->add($rec1);
    $coll->add($rec2);

    # For easiness, just compare the number of keys in each record before and 
    # after purging.
    my $retval = $coll->coll_map(sub{my $rec = shift; return scalar keys %{$rec}});
    is_deeply($retval, [6, 6]);

    $coll->purge();

    $retval = $coll->coll_map(sub{my $rec = shift; return scalar keys %{$rec}});
    is_deeply($retval, [5, 5]);

    return;
}

