package RecordTest;
use strict;
use warnings;

use base qw(Test::Unit::TestCase);

use Benchmark qw(:all);
use Data::Dumper;
use Idval::Record;

sub new {
    my $self = shift()->SUPER::new(@_);
    # your state for fixture here
    return $self;
}

sub set_up {
}

sub tear_down {
}

sub test_diff_eq
{
    my $self = shift;

    my $rec1 = Idval::Record->new('foo');
    $rec1->add_tag('GOBBLE', 'hobble');
    my $rec2 = Idval::Record->new('foo');
    $rec2->add_tag('GOBBLE', 'hobble');

    my $retval = $rec1->diff($rec2);
    $self->assert_equals(0, $retval);

    my @retval = $rec1->diff($rec2);
    $self->assert_deep_equals([{}, {}, {}], \@retval);

    return;
}

sub test_diff_ne_add_tag
{
    my $self = shift;

    my $rec1 = Idval::Record->new('foo');
    $rec1->add_tag('GOBBLE', 'hobble');
    my $rec2 = Idval::Record->new('foo');
    $rec2->add_tag('GOBBLE', 'hobble');
    $rec2->add_tag('BOBBLE', 'bobble');

    my $retval = $rec1->diff($rec2);
    $self->assert_equals(1, $retval);

    my @retval = $rec1->diff($rec2);
    $self->assert_deep_equals([{}, {}, {'BOBBLE' => 'bobble'}], \@retval);

    return;
}

sub test_diff_ne_delete_tag
{
    my $self = shift;

    my $rec1 = Idval::Record->new('foo');
    $rec1->add_tag('GOBBLE', 'hobble');
    $rec1->add_tag('BOBBLE', 'bobble');
    my $rec2 = Idval::Record->new('foo');
    $rec2->add_tag('GOBBLE', 'hobble');

    my $retval = $rec1->diff($rec2);
    $self->assert_equals(1, $retval);

    my @retval = $rec1->diff($rec2);
    $self->assert_deep_equals([{'BOBBLE' => 'bobble'}, {}, {}], \@retval);

    return;
}

sub test_diff_ne_change_tag
{
    my $self = shift;

    my $rec1 = Idval::Record->new('foo');
    $rec1->add_tag('GOBBLE', 'hobble');
    my $rec2 = Idval::Record->new('foo');
    $rec2->add_tag('GOBBLE', 'wobble');

    my $retval = $rec1->diff($rec2);
    $self->assert_equals(1, $retval);

    my @retval = $rec1->diff($rec2);
    $self->assert_deep_equals([{},
                           {'GOBBLE' => [
                                         'hobble',
                                         'wobble'
                                        ]}, {}], \@retval);

    return;
}

1;
