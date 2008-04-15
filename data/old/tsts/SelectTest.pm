package SelectTest;
use base qw(Test::Unit::TestCase);

use Data::Dumper;
use Idval::Select;

sub new {
    my $self = shift()->SUPER::new(@_);
    # your state for fixture here
    return $self;
}

sub set_up {
    # provide fixture
}
sub tear_down {
    # clean up after test
}

sub test_create
{
    my $self = shift;
    my $data = [];
    my $obj = Idval::Select->new($data);
    $self->assert_not_null($obj);
}

sub test_select_1
{
    my $self = shift;
    my $selectors = [['FOO', '=', 'goo']];
    my $obj = Idval::Select->new($selectors);
    $self->assert_equals(1, $obj->evaluate({FOO => 'goo'}));
}

sub test_select_2
{
    my $self = shift;
    my $selectors = [['FOO', '=', 'goo']];
    my $obj = Idval::Select->new($selectors);

    #print STDERR "1 sel is: ", Dumper($obj->{SELECTORS});
    #${$selectors}[0] = ['HUFF', '=', 'PUFF'];
    #print STDERR "2 sel is: ", Dumper($obj->{SELECTORS});
    $self->assert_equals(0, $obj->evaluate({FOO => 'foo'}));
}

# Handles multiple selectors and numeric values
sub test_select_3
{
    my $self = shift;
    my $selectors = [['FOO', '=', 'goo'], ['BOO', '=', 49], ];
    my $obj = Idval::Select->new($selectors);

    $self->assert_equals(1, $obj->evaluate({FOO => 'goo',
                                           BOO => 49}));
}

# Selection fails if a selector key is not present when queried
sub test_select_4
{
    my $self = shift;
    my $selectors = [['FOO', '=', 'goo'], ['BOO', '=', 49], ];
    my $obj = Idval::Select->new($selectors);

    $self->assert_equals(0, $obj->evaluate({FOO => 'goo'}));
}

# Test the various operators
sub test_select_all_ops_1
{
    my $self = shift;
    my $selectors = [['FOO', '=', 'goo'],
                     ['BOO', 'eq', 49],
                     ['A', 'has', 'ddd'],
                     ['B', '!=', 22],
                     ['C', 'ne', 'Q'],
                     ['D', '=~', 'qwerty'],
                     ['E', '!~', 'qwerty'],
                     ['F', '<',  'qqq'],
                     ['G', 'lt', 33],
                     ['H', '>', 'qqq'],
                     ['I', 'gt', 33],
                    ];

    my $obj = Idval::Select->new($selectors);

    $self->assert_equals(1, $obj->evaluate(
                                       {FOO => 'goo',
                                        BOO => 49,
                                        A => 'forty-two dddd forty-three',
                                        B => 33,
                                        C => 'P',
                                        D => 'scubbity-doo qwerty for you!',
                                        E => 'scubbity-doo qwert for you!',
                                        F => 'qqp',
                                        G => 32,
                                        H => 'qqr',
                                        I => 34,
                                       }));
}

sub test_select_all_ops_2
{
    my $self = shift;
    my $selectors = [['A', '<=', 'ddd'],
                     ['B', 'le', 22],
                     ['C', '>=', 'Q'],
                     ['D', 'ge', 33],
                    ];

    my $obj = Idval::Select->new($selectors);

    $self->assert_equals(1, $obj->evaluate(
                                       {
                                        A => 'ddd',
                                        B => 22,
                                        C => 'R',
                                        D => 33,
                                       }));
}

#Selectors with duplicate keys should be ORed together
sub test_select_OR_1
{
    my $self = shift;
    my $selectors = [['A', '=', 'ddd'],
                     ['B', 'le', 22],
                     ['A', '=', 'Q'],
                    ];

    my $obj = Idval::Select->new($selectors);

    $self->assert_equals(1, $obj->evaluate(
                                       {
                                        A => 'ddd',
                                        B => 22,
                                       }));

    $self->assert_equals(1, $obj->evaluate(
                                       {
                                        A => 'Q',
                                        B => 22,
                                       }));
}

sub test_select_OR_2
{
    my $self = shift;
    my $selectors = [['A', '=', 'ddd'],
                     ['B', 'le', 22],
                     ['A', '=', 'Q'],
                     ['B', 'eq', 42],
                    ];

    my $obj = Idval::Select->new($selectors);

    $self->assert_equals(1, $obj->evaluate(
                                       {
                                        A => 'ddd',
                                        B => 22,
                                       }));

    $self->assert_equals(1, $obj->evaluate(
                                       {
                                        A => 'Q',
                                        B => 22,
                                       }));

    $self->assert_equals(1, $obj->evaluate(
                                       {
                                        A => 'ddd',
                                        B => 42,
                                       }));

    $self->assert_equals(1, $obj->evaluate(
                                       {
                                        A => 'Q',
                                        B => 42,
                                       }));
}

1;
