package DataFileTest;
use strict;
use warnings;

use base qw(Test::Unit::TestCase);

use Benchmark qw(:all);
use Data::Dumper;

use Idval::DataFile;
use Idval::FileIO;
use Idval::ServiceLocator;

my $tree1 = {'testdir' => {}};
my $testresult;

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

# sub test_split_1
# {
#     my $self = shift;
#     my $data = "\n\n";
#     my $obj = Idval::Config->new(\$data);

#     $self->assert_deep_equals(['ho', 'hi'], $obj->split_value("ho hi"));
#     $self->assert_deep_equals(['ha ho', 'hi'], $obj->split_value("\"ha ho\" hi"));
#     $self->assert_deep_equals(['ha', 'ho hi'], $obj->split_value("ha 'ho hi'"));
# }
package Idval::DataFileSubst1;
use base qw(Idval::DataFile);

sub parse_block
{
    my $self = shift;
    my $blockref = shift;

    # Make a copy to save the information...
    push(@{$self->{TESTRESULT}}, [@{$blockref}]);

    return;
}

package DataFileTest;

# # sub test_parse_block_bogus_tag_1
# # {
# #     my $self = shift;
# #     my $br = [" gubber foo = 99",
# #         ];

# #     my $obj = Idval::DataFile->new();
# #     my $val;
# #     eval {$val = $obj->parse_block($br)};
# #     my $str = $@;
# #     $self->assert_matches(qr'Unrecognized line in tag data file: " gubber foo = 99"', $str);
# # }

# # sub test_parse_block_bogus_tag_2
# # {
# #     my $self = shift;
# #     my $br = [" foo = 99",
# #         ];

# #     my $obj = Idval::DataFile->new();
# #     my $val;
# #     eval {$val = $obj->parse_block($br)};
# #     my $str = $@;
# #     $self->assert_matches(qr'Unrecognized line in tag data file: " foo = 99"', $str);
# # }

# # sub test_parse_block_no_FILE_tag
# # {
# #     my $self = shift;
# #     my $br = ["foo = 99",
# #         ];

# #     my $obj = Idval::DataFile->new();
# #     my $val;
# #     eval {$val = $obj->parse_block($br)};
# #     my $str = $@;
# #     $self->assert_matches(qr'No FILE tag in tag data record "foo = 99"', $str);
# # }

# # sub test_parse_block_ok
# # {
# #     my $self = shift;
# #     my $br = ["FILE = gubber/hoo",
# #               "foo = 99",
# #         ];

# #     my $obj = Idval::DataFile->new();
# #     my $val = $obj->parse_block($br);
# #     $self->assert_equals('gubber/hoo', $val->get_name());
# #     $self->assert_equals('99', $val->get_value('foo'));
# # }

sub test_get_one_block_ok
{
    my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt', "\nFILE=hartford+vassar1974-10-13t04.ogg\nALBUM=Foo Har Har\n\n");

    my $obj = Idval::DataFile->new('/testdir/gt1.txt');
    my $coll = $obj->get_reclist();
    $self->assert_equals('Idval::Collection', ref $coll);
    my $rec = $coll->get_value('hartford+vassar1974-10-13t04.ogg');
    $self->assert_equals('hartford+vassar1974-10-13t04.ogg',
                         $rec->get_name());

    return;
}

sub test_plus_equals_yields_array
{
    my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt', "\nFILE=hartford+vassar1974-10-13t04.ogg\nGARBLE=Foo Har Har\nGARBLE+=Hoo Lar Lar\n\n");

    my $obj = Idval::DataFile->new('/testdir/gt1.txt');
    my $coll = $obj->get_reclist();
    $self->assert_equals('Idval::Collection', ref $coll);
    my $rec = $coll->get_value('hartford+vassar1974-10-13t04.ogg');
    print STDERR Dumper($rec);
    $self->assert_deep_equals(['Foo Har Har', 'Hoo Lar Lar'],
                              $rec->get_value('GARBLE'));

    return;
}

# sub test_get_one_block
# {
#     my $self = shift;
#     Idval::FileString::idv_add_file('/testdir/gt1.txt', "\nFILE=hartford+vassar1974-10-13t04.ogg\nALBUM=Foo Har Har\n\n");
#     #my $obj = Idval::DataFile->new('/testdir/gt1.txt');
#     my $obj = Idval::DataFileSubst1->new('/testdir/gt1.txt');
#     my $blockref = $obj->{TESTRESULT};
#     $self->assert_equals(1, scalar(@{$blockref}));
#     $self->assert_deep_equals( ['FILE=hartford+vassar1974-10-13t04.ogg',
#                                 'ALBUM=Foo Har Har'], $$blockref[0]);
# }

# sub test_get_two_blocks
# {
#     my $self = shift;
#     Idval::FileString::idv_add_file('/testdir/gt1.txt', "\nFILE=hartford+vassar1974-10-13t04.ogg\nALBUM=Foo Har Har\n\n" .
#         "\nFILE=hartford+vassar1974-10-13t05.ogg\nALBUM=Boo Goos\n\n");
#     #my $obj = Idval::DataFile->new('/testdir/gt1.txt');
#     my $obj = Idval::DataFileSubst1->new('/testdir/gt1.txt');
#     my $blockref = $obj->{TESTRESULT};
#     $self->assert_equals(2, scalar(@{$blockref}));
#     $self->assert_deep_equals( ['FILE=hartford+vassar1974-10-13t04.ogg',
#                                 'ALBUM=Foo Har Har'], $$blockref[0]);
#     $self->assert_deep_equals( ['FILE=hartford+vassar1974-10-13t05.ogg',
#                                 'ALBUM=Boo Goos'], $$blockref[1]);
# }

# sub test_get_one_block_with_continuation_line
# {
#     my $self = shift;
#     Idval::FileString::idv_add_file('/testdir/gt1.txt', "\nFILE=hartford+vassar1974-10-13t04.ogg\nALBUM=Foo Har Har\n  Guff\n\n");
#     #my $obj = Idval::DataFile->new('/testdir/gt1.txt');
#     my $obj = Idval::DataFileSubst1->new('/testdir/gt1.txt');
#     my $blockref = $obj->{TESTRESULT};
#     $self->assert_equals(1, scalar(@{$blockref}));
#     $self->assert_deep_equals( ['FILE=hartford+vassar1974-10-13t04.ogg',
#                                 "ALBUM=Foo Har Har\nGuff"], $$blockref[0]);
# }







# sub test_get_one_record
# {
#     my $self = shift;
#     Idval::FileString::idv_add_file('/testdir/gt1.txt', "\nFILE=hartford+vassar1974-10-13t04.ogg\nALBUM=Foo Har Har\n\n");
#     my $obj = Idval::DataFile->new('/testdir/gt1.txt');
#     my $reclist = $obj->get_reclist();
#     print Dumper($reclist);
#     $self->assert_equals("Foo Har Har", $reclist->get('hartford+vassar1974-10-13t04.ogg')->get_value('ALBUM'));
# }

# # Each block must have a "FILE" entry
# sub test_get1
# {
#     my $self = shift;
#     Idval::FileString::idv_add_file('/testdir/gt1.txt', "\nBILE=hartford+vassar1974-10-13t04.ogg\nALBUM=Foo Har Har\n\n");
#     my $obj;
#     eval {$obj = Idval::DataFile->new('/testdir/gt1.txt')};
#     my $str = $@;
#     $self->assert_null($obj);
#     $self->assert_matches(qr'Unrecognized file contents: no "FILE" found.', $str);
# }

# sub test_continuation
# {
#     my $self = shift;
#     Idval::FileString::idv_add_file('/testdir/gt1.txt', "\nFILE=hartford+vassar1974-10-13t04.ogg\nALBUM=Foo Har Har\n  Ho Ho Ho\n\n");
#     my $obj;
#     $obj = Idval::DataFile->new('/testdir/gt1.txt');
#     my $reclist = $obj->get_reclist();
#     $self->assert_equals("Foo Har Har\n    Ho Ho Ho", $reclist->{'hartford+vassar1974-10-13t04.ogg'}->get_value('ALBUM'));
# }

# sub test_get_with_strange_chars
# {
#     my $self = shift;
#     my $data = "\ngubber = pachoo\r\n\rhubber=4\n\n";
#     my $obj = Idval::Config->new(\$data);
#     $self->assert_equals('pachoo', $obj->get_single_value('gubber'));
#     $self->assert_equals(4, $obj->get_single_value('hubber'));
# }

# sub test_get_list_1
# {
#     my $self = shift;
#     my $data = "\ngubber = pachoo wachoo\n\n";
#     my $obj = Idval::Config->new(\$data);
#     $self->assert_deep_equals(['pachoo', 'wachoo'], $obj->get_value('gubber'));
# }

# sub test_get_list_2
# {
#     my $self = shift;
#     my $data = "\ngubber = pachoo\ngubber += wachoo\n\n";
#     my $obj = Idval::Config->new(\$data);
#     $self->assert_deep_equals(['pachoo', 'wachoo'], $obj->get_value('gubber'));
# }

# sub test_get_list_3
# {
#     my $self = shift;
#     my $data = "\ngubber = pachoo nachoo \"huggery muggery\" hoofah\n\n";
#     my $obj = Idval::Config->new(\$data);
#     $self->assert_deep_equals(['pachoo', 'nachoo', 'huggery muggery', 'hoofah'], $obj->get_value('gubber'));
# }

# sub test_get_list_4
# {
#     my $self = shift;
#     my $data = "\ngubber = pachoo nachoo \"huggery muggery\" hoofah\n\n";
#     my $obj = Idval::Config->new(\$data);
#     $self->assert_deep_equals(['pachoo', 'nachoo', 'huggery muggery', 'hoofah'], $obj->get_value('gubber'));
# }

# # Not correct to call keyword routines from outside

# sub test_block_1
# {
#     my $self = shift;
#     my $data = "\ngubber = pachoo wachoo\n\n";
#     my $obj = Idval::Config->new(\$data);
#     $self->assert_deep_equals(['pachoo', 'wachoo'], $obj->get_value('gubber'));
# }

# sub test_block_two_blocks_ok
# {
#     my $self = shift;
#     my $data = "\ngubber = pachoo wachoo\n\n\nrubber = bouncy\n\n";
#     my $obj = Idval::Config->new(\$data);

#     $self->assert_deep_equals(['pachoo', 'wachoo'], $obj->get_value('gubber'));
#     $self->assert_equals('bouncy', $obj->get_single_value('rubber'));
# }

# sub test_block_two_blocks_append
# {
#     my $self = shift;
#     my $data = "\ngubber = pachoo wachoo\n\n\ngubber += bouncy\n\n";
#     my $obj = Idval::Config->new(\$data);

#     $self->assert_deep_equals(['pachoo', 'wachoo', 'bouncy'], $obj->get_value('gubber'));
# }

# sub test_block_two_blocks_replace
# {
#     my $self = shift;
#     my $data = "\ngubber = pachoo wachoo\n\n\ngubber = bouncy\n\n";
#     my $obj = Idval::Config->new(\$data);

#     $self->assert_deep_equals(['bouncy'], $obj->get_value('gubber'));
#     $self->assert_equals('bouncy', $obj->get_single_value('gubber'));
# }

# # # Memoization wins; about twice as fast
# # sub test_benchmark_select_1
# # {
# #     my $self = shift;
# #     my $data = "\nSELECT type = foo\ngubber = pachoo wachoo\n\n\nSELECT type = boo\ngubber = bouncy\n\n";
# #     my $obj = Idval::Config->new(\$data);

# #     my $bm1 = timethis(300000, sub {$obj->get_value("gubber", {"type" => "foo"})});
# #     my $bm2 = timethis(300000, sub {$obj->get_value_memo("gubber", {"type" => "foo"})});

# #     print STDERR "non-memo took ", timestr($bm1), "\n";
# #     print STDERR "memo took ", timestr($bm2), "\n";
# # }

# # Memoization wins; about three times as fast
# # sub test_benchmark_select_1
# # {
# #     my $self = shift;
# #     my $data = "\ntype = foo\ngubber = pachoo wachoo\n\n\ntype = boo\ngubber = bouncy\n\n";
# #     my $obj = Idval::Config->new(\$data);

# #     my $bm1 = timethis(300000, sub {$obj->get_single_value("gubber", [['type', '=', 'foo']])});
# #     my $bm2 = timethis(300000, sub {$obj->no_memo_get_single_value("gubber", [['type', '=', 'foo']])});

# #     print STDERR "\nmemo took ", timestr($bm1), "\n";
# #     print STDERR "non-memo took ", timestr($bm2), "\n";
# # }

# sub test_block_two_blocks_select_1
# {
#     my $self = shift;
#     my $data = "\ntype = foo\ngubber = pachoo wachoo\n\n\ntype = boo\ngubber = bouncy\n\n";
#     my $obj = Idval::Config->new(\$data);

#     $self->assert_deep_equals(['pachoo', 'wachoo'], $obj->get_value('gubber', [['type', '=', 'foo']]));
# }

# sub test_other_keywords_1
# {
#     my $self = shift;
#     my $data = "\ntype = foo\nTAGNAME TYPE = CLASS\n\n";
#     my $obj = Idval::Config->new(\$data);

#     $self->assert_deep_equals([['TYPE', '=', 'CLASS']], $obj->get_keyword_value('TAGNAME', [['type', '=', 'foo']]));
# }

# sub test_other_keywords_2
# {
#     my $self = shift;
#     my $data = "\ntype = foo\nVALUE ALBUM =~ /^foo/\n\n";
#     my $obj = Idval::Config->new(\$data);

#     $self->assert_deep_equals([['ALBUM', '=~', '/^foo/']], $obj->get_keyword_value('VALUE', [['type', '=', 'foo']]));
# }

# sub test_two_files_1
# {
#     my $self = shift;
#     my $data1 = "\ngubber = pachoo wachoo\n\n";
#     my $data2 = "\nrubber = bouncy\n\n";
#     my $obj = Idval::Config->new(\$data1, \$data2);

#     $self->assert_deep_equals(['pachoo', 'wachoo'], $obj->get_value('gubber'));
#     $self->assert_equals('bouncy', $obj->get_single_value('rubber'));
# }

# sub test_magic_word_1
# {
#     my $self = shift;
#     my $data = "\ngubber = {DATA}/pachoo wachoo/{DATA}/boo\n\n";
#     my $obj = Idval::Config->new(\$data);
#     $self->assert_deep_equals(["$datadir/pachoo", "wachoo/$datadir/boo"], $obj->get_value('gubber'));
# }

# sub test_eval_1
# {
#     my $self = shift;
#     my $data = "\ngubber = pachoo\r\n\rhubber=4\n\n";
#     my $obj = Idval::Config->new(\$data);
#     my $block = ${$obj->{BLOCKS}}[0];

#     my $retval = $block->evaluate([['gubber', '=', 'pachoo']]);
#     $self->assert_num_equals($retval, 1);

#     $retval = $block->evaluate([['gubber', '!=', 'pachoo']]);
#     $self->assert_num_equals($retval, 0);

#     $retval = $block->evaluate([['gubber', '=~', 'p[aeiou]choo']]);
#     $self->assert_num_equals($retval, 1);

#     $retval = $block->evaluate([['gubber', 'has', 'choo']]);
#     $self->assert_num_equals($retval, 1);

# }

# sub test_eval_2
# {
#     my $self = shift;
#     my $data = "\ngubber = pachoo\r\n\rhubber=4\n\n";
#     my $obj = Idval::Config->new(\$data);
#     my $block = ${$obj->{BLOCKS}}[0];

#     my $retval = $block->evaluate([['gubber', '=', 'pachoo'], ['hubber', '=', 4]]);
#     $self->assert_num_equals(1, $retval);

#     $retval = $block->evaluate([['gubber', '=', 'pachoo'], ['hubber', '=', 3]]);
#     $self->assert_num_equals(0, $retval);

# }

# # Check behavior with select keys that don't exist in config block
# sub test_eval_3
# {
#     my $self = shift;
#     my $data = "\ngubber = pachoo\r\n\rhubber=4\n\n";
#     my $obj = Idval::Config->new(\$data);
#     my $block = ${$obj->{BLOCKS}}[0];

#     my $retval = $block->evaluate([['gubber', '=', 'pachoo'], ['blubber', '=', 4]]);
#     $self->assert_num_equals($retval, 0);

#     $retval = $block->evaluate([['gubber', '=', 'pachoo'], ['blubber', '=', 4]], 1);
#     $self->assert_num_equals($retval, 1);

#     $retval = $block->evaluate([['gubber', '=', 'nope'], ['blubber', '=', 4]], 1);
#     $self->assert_num_equals($retval, 0);
# }


# # Check behavior with duplicate select keys
# sub test_eval_4
# {
#     my $self = shift;
#     my $data = "\ngubber = pachoo\r\n\rhubber=4\n\n";
#     my $obj = Idval::Config->new(\$data);
#     my $block = ${$obj->{BLOCKS}}[0];

#     my $retval = $block->evaluate([['gubber', '=', 'frizzle'], ['gubber', '=', 'pachoo']]);
#     $self->assert_num_equals($retval, 1);

#     $retval = $block->evaluate([['gubber', '=', 'frizzle'], ['gubber', '=', 'gizzard']]);
#     $self->assert_num_equals($retval, 0);

# }

1;
