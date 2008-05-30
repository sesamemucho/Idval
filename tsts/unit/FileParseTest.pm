package FileParseTest;
use strict;
use warnings;

use base qw(Test::Unit::TestCase);

use Benchmark qw(:all);
use Data::Dumper;

use Idval::FileIO;
use Idval::ServiceLocator;
use Idval::FileParse;

my $tree1 = {'testdir' => {}};

sub new {
    my $self = shift()->SUPER::new(@_);
    # your state for fixture here
    # Tell the system to use the string-based filesystem services (i.e., the unit-testing version)
    Idval::ServiceLocator::provide('io_type', 'FileString');
    return $self;
}

sub set_up {
    # provide fixture
    Idval::FileString::idv_set_tree($tree1);

    return;
}

sub tear_down {
    # clean up after test
    Idval::FileString::idv_clear_tree();

    return;
}

sub test_create {
    my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt', "\n\n");
    my $reader = FakeReader_FPT->new();
    my $obj = Idval::FileParse->new($reader, '/testdir/gt1.txt');
    $self->assert_not_null($obj);

    return;
}

sub test_basic
{
    my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt', "a = 4\nboo = hoo\n");
    #my $data = "a = 4\nboo = hoo\n";
    my $reader = FakeReader_FPT->new();
    my $obj = Idval::FileParse->new($reader, '/testdir/gt1.txt');

    my $result = $obj->parse();

    $self->assert_deep_equals([{'a' => '4','boo' => 'hoo',}], $result);

    return;
}

sub test_no_comments
{
    my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt', "a = 4\n#comment\nboo = hoo\n");
    my $reader = FakeReader_FPT->new();
    my $obj = Idval::FileParse->new($reader, '/testdir/gt1.txt');

    my $result = $obj->parse();

    $self->assert_deep_equals([{'a' => '4'},{'boo' => 'hoo',}], $result);

    return;
}

sub test_plusequals
{
    my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt', "a = 4\nboo = hoo\na += 3");
    my $reader = FakeReader_FPT->new();
    my $obj = Idval::FileParse->new($reader, '/testdir/gt1.txt');

    my $result = $obj->parse();

    $self->assert_deep_equals([{'a' => '4 3','boo' => 'hoo',}], $result);

    return;
}

sub test_append
{
    my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt', "a = 4\nboo = hoo\n  3");
    my $reader = FakeReader_FPT->new();
    my $obj = Idval::FileParse->new($reader, '/testdir/gt1.txt');

    my $result = $obj->parse();

    $self->assert_deep_equals([{'a' => '4','boo' => 'hoo 3',}], $result);

    return;
}

sub test_two_blocks
{
    my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt', "a = 4\nboo = hoo\n\n\ngak = bak\nhuf = fuf\n");
    my $reader = FakeReader_FPT->new();
    my $obj = Idval::FileParse->new($reader, '/testdir/gt1.txt');

    my $result = $obj->parse();

    $self->assert_deep_equals([{'a' => '4','boo' => 'hoo',},
                              {'gak' => 'bak','huf' => 'fuf'}], $result);

    return;
}

sub test_two_inputs
{
    my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt', "a = 4\nboo = hoo\n");
    Idval::FileString::idv_add_file('/testdir/gt2.txt', "gak = bak\nhuf = fuf\n");
    my $reader = FakeReader_FPT->new();
    my $obj = Idval::FileParse->new($reader, '/testdir/gt1.txt', '/testdir/gt2.txt');

    my $result = $obj->parse();

    $self->assert_deep_equals([{'a' => '4','boo' => 'hoo',},
                              {'gak' => 'bak','huf' => 'fuf'}], $result);

    return;
}

package FakeReader_FPT;
use Data::Dumper;
sub new
{
    my $class = shift;
    my $self = {};
    bless($self, ref($class) || $class);
    $self->_init(@_);
    return $self;
}

sub _init
{
    my $self = shift;
    my @args = @_;
    $self->{DATA} = {};

    return;
}

sub get_keyword_set
{
    my $self = shift;

    return 'SELECT|TAGNAME|VALUE|GUBBER';
}

sub store_value
{
    my $self = shift;
    my $op = shift;
    my $tag = shift;
    my $value = shift;

    if ($op eq '=')
    {
        if (exists($self->{DATA}->{$tag}))
        {
            $self->{DATA}->{$tag} .= ' ' . $value;
        }
        else
        {
            $self->{DATA}->{$tag} = $value;
        }
    }
    else
    {
        $self->{DATA}->{$tag} .= ' ' . $value;
    }

    return;
}

sub store_keyword_value
{
    my $self = shift;
    my $kw = shift;
    my $tag = shift;
    my $op = shift;
    my $value = shift;

    $self->{DATA}->{$tag} = "$kw $tag $op $value";

    return;
}

# Split the input text into blocks and return a list
sub get_blocks
{
    my $self = shift;
    my $text = shift;


   return split(/\n\n+/, $text);
}

sub start_block
{
    my $self = shift;

    return;
}

# Make a copy and return that
sub get_block
{
    my $self = shift;
    my %block;

    foreach my $key (keys %{$self->{DATA}})
    {
        $block{$key} = $self->{DATA}->{$key};
    }

    delete $self->{DATA};

    return \%block;
}

sub add_block
{
    my $self = shift;
    my $collection = shift;
    my $block = shift;

    confess ("Not an ARRAY reference (", ref $collection, ")\n") if ref $collection eq 'HASH';
    push(@{$collection}, $block);

    return;
}

sub collection_type
{
    my $self = shift;

    return 'ARRAY';
}

1;
