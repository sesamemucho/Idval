package Idval::Record::Test;
use strict;
use warnings;
use lib qw{t/lib};

use base qw(Test::Class);
use Test::More;

use Data::Dumper;
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

sub difference_of_equal_records_shows_equality : Test(2)
{
    my $rec1 = Idval::Record->new({FILE=>'foo'});
    $rec1->add_tag('GOBBLE', 'hobble');
    my $rec2 = Idval::Record->new({FILE=>'foo'});
    $rec2->add_tag('GOBBLE', 'hobble');

    my $retval = $rec1->diff($rec2);
    ok(not $retval);

    my @retval = $rec1->diff($rec2);
    is_deeply(\@retval, [{}, {}, {}]);

    return;
}

sub difference_with_added_tag_shows_added_tag : Test(2)
{
    my $rec1 = Idval::Record->new({FILE=>'foo'});
    $rec1->add_tag('GOBBLE', 'hobble');
    my $rec2 = Idval::Record->new({FILE=>'foo'});
    $rec2->add_tag('GOBBLE', 'hobble');
    $rec2->add_tag('BOBBLE', 'bobble');

    my $retval = $rec1->diff($rec2);
    ok($retval);

    my @retval = $rec1->diff($rec2);
    is_deeply(\@retval, [{}, {}, {'BOBBLE' => 'bobble'}]);

    return;
}

sub difference_with_deleted_tag_shows_deleted_tag : Test(2)
{
    my $rec1 = Idval::Record->new({FILE=>'foo'});
    $rec1->add_tag('GOBBLE', 'hobble');
    $rec1->add_tag('BOBBLE', 'bobble');
    my $rec2 = Idval::Record->new({FILE=>'foo'});
    $rec2->add_tag('GOBBLE', 'hobble');

    my $retval = $rec1->diff($rec2);
    ok($retval);

    my @retval = $rec1->diff($rec2);
    is_deeply(\@retval, [{'BOBBLE' => 'bobble'}, {}, {}]);

    return;
}

sub difference_with_changed_tag_shows_changes : Test(2)
{
    my $rec1 = Idval::Record->new({FILE=>'foo'});
    $rec1->add_tag('GOBBLE', 'hobble');
    my $rec2 = Idval::Record->new({FILE=>'foo'});
    $rec2->add_tag('GOBBLE', 'wobble');

    my $retval = $rec1->diff($rec2);
    ok($retval);

    my @retval = $rec1->diff($rec2);
    is_deeply(\@retval, [{},
                           {'GOBBLE' => [
                                         'hobble',
                                         'wobble'
                                        ]}, {}]);

    return;
}

1;
