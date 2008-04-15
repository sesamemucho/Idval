package FileStringTest;
use Data::Dumper;

use base qw(Test::Unit::TestCase);

use Idval::FileString;

our $tree1 = {'a' => {'a1' => {},
                      'a2' => 'foo bar goo',
                      },
              'b' => {'b1' => {
                               'b11' => 'hubba bubba'
                              },
                      'b2' => {
                               'b21' => {
                                         'b211' => 'foo hoo',
                                         },
                               },
                     }
              };
sub new {
    my $self = shift()->SUPER::new(@_);
    # your state for fixture here
    return $self;
}

sub set_up
{
}

sub tear_down
{
    # clean up after test
    Idval::FileString::idv_clear_tree();
}

sub test_getdir_1
{
    my $self = shift;
    my @result;

    Idval::FileString::idv_set_tree($tree1);

    @result = Idval::FileString::_get_dir('/');
    $self->assert_deep_equals([0, $tree1, ''], \@result);

    @result = Idval::FileString::_get_dir('/b/b1');
    $self->assert_deep_equals([0, $tree1->{'b'}->{'b1'}, ''], \@result);

    @result = Idval::FileString::_get_dir('/b/b2');
    $self->assert_deep_equals([0, $tree1->{'b'}->{'b2'}, ''], \@result);
}

sub test_getdir_2
{
    my $self = shift;
    my @result;

    Idval::FileString::idv_set_tree($tree1);

    @result = Idval::FileString::_get_dir('/garf');
    $self->assert_deep_equals([1, $tree1, 'garf'], \@result);

    @result = Idval::FileString::_get_dir('/a/b1');
    $self->assert_deep_equals([1, $tree1->{'a'}, 'b1'], \@result);

    @result = Idval::FileString::_get_dir('/a/a1/bibble/babble/bubble');
    $self->assert_deep_equals([1, $tree1->{'a'}->{'a1'}, 'bibble/babble/bubble'], \@result);

    @result = Idval::FileString::_get_dir('/b/b1/b11');
    $self->assert_deep_equals([2, 'b11', 'b11'], \@result);

    @result = Idval::FileString::_get_dir('/a/a2/goober');
    $self->assert_deep_equals([2, 'a2', 'a2/goober'], \@result);

}

sub test_get_dirname
{
    my $self = shift;
    my @result;

    Idval::FileString::idv_set_tree($tree1);

    @result = Idval::FileString::_get_dir('/b/b1');
    $self->assert_equals('/b/b1', Idval::FileString::idv_get_dirname($result[1]));
}

sub test_getdir_with_special
{
    my $self = shift;
    my @result;

    Idval::FileString::idv_set_tree($tree1);

    @result = Idval::FileString::_get_dir('/b/b1/..');
    $self->assert_deep_equals([0, $tree1->{'b'}, ''], \@result);

    @result = Idval::FileString::_get_dir('/b/b2/b21/../../b1');
    $self->assert_deep_equals([0, $tree1->{'b'}->{'b1'}, ''], \@result);

    # Can't go above the root
    @result = Idval::FileString::_get_dir('/..');
    $self->assert_deep_equals([1, $tree1, '..'], \@result);
}

sub test_getdir_1_cd
{
    my $self = shift;
    my @result;

    Idval::FileString::idv_set_tree($tree1);

    Idval::FileString::idv_cd('/b');

    @result = Idval::FileString::_get_dir('b1');
    $self->assert_deep_equals([0, $tree1->{'b'}->{'b1'}, ''], \@result);
    $self->assert_equals('/b/b1', Idval::FileString::idv_get_dirname($result[1]));

    Idval::FileString::idv_cd('b2');
    @result = Idval::FileString::_get_dir('b21');
    $self->assert_deep_equals([0, $tree1->{'b'}->{'b2'}->{'b21'}, ''], \@result);
    $self->assert_equals('/b/b2/b21', Idval::FileString::idv_get_dirname($result[1]));

    Idval::FileString::idv_cd('../../a');
    $self->assert_equals('/a', Idval::FileString::idv_get_dirname($Idval::FileString::cwd));
    @result = Idval::FileString::_get_dir('a1');
    $self->assert_deep_equals([0, $tree1->{'a'}->{'a1'}, ''], \@result);
    $self->assert_equals('/a/a1', Idval::FileString::idv_get_dirname($result[1]));
}

sub test_mkdir1
{
    my $self = shift;
    my $dir = Idval::FileString::idv_mkdir("/a/b/c");

    $self->assert_equals("HASH", ref $dir);
    $self->assert_equals(1, Idval::FileString::idv_is_ref_dir($dir));
}

sub test_mkdir2
{
    my $self = shift;
    my $dir;
    Idval::FileString::idv_set_tree($tree1);
    $dir = Idval::FileString::idv_mkdir("/a/b/c");

    $self->assert_equals(1, Idval::FileString::idv_is_ref_dir($dir));

    eval {$dir = Idval::FileString::idv_mkdir("/a/a2/goober")};
    my $str = $@;
    $self->assert_matches(qr{^A regular file \(a2\) was found while creating the directory path "/a/a2/goober"}, $str);
}

sub test_add_file
{
    my $self = shift;
    Idval::FileString::idv_add_file("/a/b/c/foo.txt", "garf\nharf\n");

    $self->assert_equals(1, Idval::FileString::idv_test_isfile("/a/b/c/foo.txt"));
    $self->assert_equals(0, Idval::FileString::idv_test_isfile("/a/b/c/bboo.txt"));

    Idval::FileString::idv_cd("/a/b/c");
    #$self->assert_equals('/a/b/c', Idval::FileString::idv_get_dirname($Idval::FileString::cwd));
}

sub test_new
{
    my $self = shift;
    Idval::FileString::idv_add_file("/a/b/c/foo.txt", "garf\nharf\n");

    my $io = Idval::FileString->new("/a/b/c/foo.txt", '<');

    my $line = <$io>;

    $self->assert("garf\n", $line);

}

sub test_open_1
{
    my $self = shift;
    Idval::FileString::idv_add_file("/a/b/c/foo.txt", "garf\nharf\n");

    my $io = Idval::FileString->new();
    $self->assert($io);

    $io->open("/a/b/c/foo.txt", "r");

    $self->assert("garf", $io->getline);
}

sub test_find
{
    my $self = shift;
    local @flist = ();
    Idval::FileString::idv_add_file("/a/b/c/foo.txt", "garf\nharf\n");
    Idval::FileString::idv_add_file("/a/b/goo.txt", "arf\nlarf\n");

    Idval::FileString::idv_find(sub{
                                    push(@flist, $_) if Idval::FileString::idv_test_isfile($_);
                                });

    $self->assert_deep_equals(['goo.txt', 'foo.txt'], \@flist);
}

sub test_glob_1
{
    my $self = shift;

    Idval::FileString::idv_add_file("/a/b/foo.txt", "\n");
    Idval::FileString::idv_add_file("/a/b/goo.txt", "\n");
    Idval::FileString::idv_add_file("/a/b/gah.txt", "\n");

    my @files = Idval::FileString::idv_glob("/a/b/*oo.txt");

    $self->assert_deep_equals(['/a/b/foo.txt', '/a/b/goo.txt'], \@files);
}

sub test_mkdir
{
    my $self = shift;

    Idval::FileString::idv_set_tree($tree1);

    $self->assert_equals(0, Idval::FileString::idv_test_isdir('/a/goober/hoober'));

    Idval::FileString::idv_mkdir('/a/goober/hoober');

    $self->assert_equals(1, Idval::FileString::idv_test_isdir('/a/goober/hoober'));
}

# sub test_f
# {
#     my $self = shift;
#     Idval::FileString::idv_add_file("/a/b/c/foo.txt", "garf\nharf\n");
#     Idval::FileString::idv_add_file("/a/b/goo.txt", "arf\nlarf\n");

#     $self->assert_equals(0, Idval::FileString::idv_test_isfile("/a/b"));
#     $self->assert_equals(0, Idval::FileString::idv_test_isfile("/a/b/c"));
#     $self->assert_equals(1, Idval::FileString::idv_test_isfile("/a/b/goo.txt"));
#     $self->assert_equals(1, Idval::FileString::idv_test_isfile("/a/b/c/foo.txt"));
# }

1;
