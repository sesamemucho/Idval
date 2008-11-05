package Idval::FileString::Test;
use strict;
use warnings;
use lib qw{t/lib};

use Data::Dumper;

use base qw(Test::Class);
use Test::More;

use Idval::FileString;

our @flist = ();

INIT { Test::Class->runtests } # here's the magic!

sub begin : Test(startup) {
    # your state for fixture here
    return;
}

sub end : Test(shutdown) {
    return;
}


sub before : Test(setup) {
    # provide fixture
    my $tree1 = {'a' => {'a1' => {},
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
    Idval::FileString::idv_set_tree($tree1);
    return;
}

sub after : Test(teardown) {
    # clean up after test
    Idval::FileString::idv_clear_tree();
    return;
}

## no critic (ProtectPrivateSubs)

sub getdir_1 : Test(3)
{
    my @result;

    my $tree = Idval::FileString::idv_get_tree();

    @result = Idval::FileString::_get_dir('/');
    is_deeply(\@result, [0, $tree, '']);

    @result = Idval::FileString::_get_dir('/b/b1');
    is_deeply([0, $tree->{'b'}->{'b1'}, ''], \@result);

    @result = Idval::FileString::_get_dir('/b/b2');
    is_deeply([0, $tree->{'b'}->{'b2'}, ''], \@result);

    return;
}

sub getdir_2 : Test(5)
{
    my @result;

    my $tree = Idval::FileString::idv_get_tree();

    @result = Idval::FileString::_get_dir('/garf');
    is_deeply(\@result, [1, $tree, 'garf']);

    @result = Idval::FileString::_get_dir('/a/b1');
    is_deeply(\@result, [1, $tree->{'a'}, 'b1']);

    @result = Idval::FileString::_get_dir('/a/a1/bibble/babble/bubble');
    is_deeply(\@result, [1, $tree->{'a'}->{'a1'}, 'bibble/babble/bubble']);

    @result = Idval::FileString::_get_dir('/b/b1/b11');
    is_deeply(\@result, [2, 'b11', 'b11']);

    @result = Idval::FileString::_get_dir('/a/a2/goober');
    is_deeply(\@result, [2, 'a2', 'a2/goober']);

    return;
}

sub get_dirname : Test(1)
{
    my $self = shift;
    my @result;

    @result = Idval::FileString::_get_dir('/b/b1');
    is(Idval::FileString::idv_get_dirname($result[1]), '/b/b1');

    return;
}

sub getdir_with_special : Test(3)
{
    my $self = shift;
    my @result;

    my $tree = Idval::FileString::idv_get_tree();

    @result = Idval::FileString::_get_dir('/b/b1/..');
    is_deeply(\@result, [0, $tree->{'b'}, '']);

    @result = Idval::FileString::_get_dir('/b/b2/b21/../../b1');
    is_deeply(\@result, [0, $tree->{'b'}->{'b1'}, '']);

    # Can't go above the root
    @result = Idval::FileString::_get_dir('/..');
    is_deeply(\@result, [1, $tree, '..']);

    return;
}

sub test_getdir_1_cd : Test(7)
{
    my $self = shift;
    my @result;

    my $tree = Idval::FileString::idv_get_tree();

    Idval::FileString::idv_cd('/b');

    @result = Idval::FileString::_get_dir('b1');
    is_deeply(\@result, [0, $tree->{'b'}->{'b1'}, '']);
    is(Idval::FileString::idv_get_dirname($result[1]), '/b/b1');

    Idval::FileString::idv_cd('b2');
    @result = Idval::FileString::_get_dir('b21');
    is_deeply(\@result, [0, $tree->{'b'}->{'b2'}->{'b21'}, '']);
    is(Idval::FileString::idv_get_dirname($result[1]), '/b/b2/b21');

    Idval::FileString::idv_cd('../../a');
    is(Idval::FileString::idv_get_dirname($Idval::FileString::cwd), '/a'); ## no critic (ProhibitPackageVars)
    @result = Idval::FileString::_get_dir('a1');
    is_deeply(\@result, [0, $tree->{'a'}->{'a1'}, '']);
    is(Idval::FileString::idv_get_dirname($result[1]), '/a/a1');

    return;
}

sub test_mkdir1 : Test(2)
{
    my $dir = Idval::FileString::idv_mkdir("/a/b/c");

    isa_ok($dir, "HASH");
    is(Idval::FileString::idv_is_ref_dir($dir), 1);

    return;
}

sub mkdir2 : Test(2)
{
    my $dir;

    $dir = Idval::FileString::idv_mkdir("/a/b/c");

    is(Idval::FileString::idv_is_ref_dir($dir), 1);

    eval {$dir = Idval::FileString::idv_mkdir("/a/a2/goober")};
    my $str = $@;
    like($str, qr{A regular file \(a2\) was found while creating the directory path "/a/a2/goober"});

    return;
}

sub add_file : Test(3)
{
    Idval::FileString::idv_add_file("/a/b/c/foo.txt", "garf\nharf\n");

    is(Idval::FileString::idv_test_isfile("/a/b/c/foo.txt"), 1);
    is(Idval::FileString::idv_test_isfile("/a/b/c/bboo.txt"), 0);

    Idval::FileString::idv_cd("/a/b/c");
    is(Idval::FileString::idv_get_dirname($Idval::FileString::cwd), '/a/b/c');

    return;
}

sub new_io : Test(1)
{
    Idval::FileString::idv_add_file("/a/b/c/foo.txt", "garf\nharf\n");

    my $io = Idval::FileString->new("/a/b/c/foo.txt", '<');

    my $line = <$io>;

    is($line, "garf\n");

    return;
}

sub open_1 : Test(2)
{
    Idval::FileString::idv_add_file("/a/b/c/foo.txt", "garf\nharf\n");

    my $io = Idval::FileString->new("/a/b/c/foo.txt", "r");
    ok($io);

#    $io->open("/a/b/c/foo.txt", "r");

    is($io->getline, "garf\n");

    return;
}

# sub test_find
# {
#     my $self = shift;
#     local @flist;
#     Idval::FileString::idv_add_file("/a/b/c/foo.txt", "garf\nharf\n");
#     Idval::FileString::idv_add_file("/a/b/goo.txt", "arf\nlarf\n");

#     Idval::FileString::idv_find(sub{
#                                     push(@flist, $_) if Idval::FileString::idv_test_isfile($_);
#                                 });

#     is_deeply(['goo.txt', 'foo.txt'], \@flist);

#     return;
# }

# sub test_glob_star_matches
# {
#     my $self = shift;

#     Idval::FileString::idv_add_file("/a/b/foo.txt", "\n");
#     Idval::FileString::idv_add_file("/a/b/goo.txt", "\n");
#     Idval::FileString::idv_add_file("/a/b/gah.txt", "\n");

#     my @files = Idval::FileString::idv_glob("/a/b/*oo.txt");

#     is_deeply(\@files, ['/a/b/foo.txt', '/a/b/goo.txt']);

#     return;
# }

# sub test_glob_question_matches
# {
#     my $self = shift;

#     Idval::FileString::idv_add_file("/a/b/foo.txt", "\n");
#     Idval::FileString::idv_add_file("/a/b/goo.txt", "\n");
#     Idval::FileString::idv_add_file("/a/b/gah.txt", "\n");

#     my @files = Idval::FileString::idv_glob("/a/b/?oo.txt");

#     is_deeply(\@files, ['/a/b/foo.txt', '/a/b/goo.txt']);

#     return;
# }

# sub test_glob_exact_matches
# {
#     my $self = shift;

#     Idval::FileString::idv_add_file("/a/b/foo.txt", "\n");
#     Idval::FileString::idv_add_file("/a/b/goo.txt", "\n");
#     Idval::FileString::idv_add_file("/a/b/gah.txt", "\n");

#     my @files = Idval::FileString::idv_glob("/a/b/goo.txt");

#     is_deeply(\@files, ['/a/b/goo.txt']);

#     return;
# }

# sub test_mkdir
# {
#     my $self = shift;

#     Idval::FileString::idv_set_tree($tree1);

#     is(Idval::FileString::idv_test_isdir('/a/goober/hoober'), 0);

#     Idval::FileString::idv_mkdir('/a/goober/hoober');

#     is(Idval::FileString::idv_test_isdir('/a/goober/hoober'), 1);

#     return;
# }






# # sub test_f
# # {
# #     my $self = shift;
# #     Idval::FileString::idv_add_file("/a/b/c/foo.txt", "garf\nharf\n");
# #     Idval::FileString::idv_add_file("/a/b/goo.txt", "arf\nlarf\n");

# #     is(Idval::FileString::idv_test_isfile("/a/b"), 0);
# #     is(Idval::FileString::idv_test_isfile("/a/b/c"), 0);
# #     is(Idval::FileString::idv_test_isfile("/a/b/goo.txt"), 1);
# #     is(Idval::FileString::idv_test_isfile("/a/b/c/foo.txt"), 1);
# # }

1;
