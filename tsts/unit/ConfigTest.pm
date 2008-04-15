package ConfigTest;
use base qw(Test::Unit::TestCase);

use Benchmark qw(:all);
use Data::Dumper;
use FindBin;
use Memoize;


use Idval::Config;
use Idval::FileIO;
use Idval::ServiceLocator;

our $tree1 = {'testdir' => {}};

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
}
sub tear_down {
    # clean up after test
    Idval::FileString::idv_clear_tree();
}

sub barf_test_get
{
    my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt', "\ngubber = 3\nhubber=4\n\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt');
    $self->assert_equals(3, $obj->get_single_value('gubber'));
    $self->assert_equals(4, $obj->get_single_value('hubber'));
}

sub barf_test_get_with_strange_chars
{
    my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt', "\ngubber = pachoo\r\n\rhubber=4\n\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt');
    $self->assert_equals('pachoo', $obj->get_single_value('gubber'));
    $self->assert_equals(4, $obj->get_single_value('hubber'));
}

# Test that we get the default default
sub barf_test_get_with_default1
{
    my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt', "\ngubber = 3\nhubber=4\n\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt');
    $self->assert_equals('', $obj->get_single_value('flubber'));
}

sub barf_test_get_with_default2
{
    my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt', "\ngubber = 3\nhubber=4\n\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt');
    $self->assert_equals(18, $obj->get_single_value('flubber', {}, 18));
}

sub barf_test_get_list_1
{
    my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt', "\ngubber = pachoo wachoo\n\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt');
    $self->assert_equals('pachoo wachoo', $obj->get_value('gubber'));
}

# # An append should replace an assignment in the same block
# sub test_get_list_2
# {
#     my $self = shift;
#     Idval::FileString::idv_add_file('/testdir/gt1.txt', "\ngubber = pachoo\ngubber += wachoo\n\n");
#     my $obj = Idval::Config->new('/testdir/gt1.txt');
#     $self->assert_deep_equals(['wachoo'], $obj->get_value('gubber'));
# }

# # An append by itself should append to nothing
# sub test_get_list_2a
# {
#     my $self = shift;
#     Idval::FileString::idv_add_file('/testdir/gt1.txt', "\ngubber += wachoo\n\n");
#     my $obj = Idval::Config->new('/testdir/gt1.txt');
#     $self->assert_deep_equals(['wachoo'], $obj->get_value('gubber'));
# }

# # An append after something other than an assignment should replace
# sub test_get_list_2b
# {
#     my $self = shift;
#     Idval::FileString::idv_add_file('/testdir/gt1.txt', "\ngubber =~ pachoo\ngubber += wachoo\n\n");
#     my $obj = Idval::Config->new('/testdir/gt1.txt');
#     $self->assert_deep_equals(['wachoo'], $obj->get_value('gubber'));
# }

sub barf_test_get_list_3
{
    my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt', "\ngubber = pachoo nachoo \"huggery muggery\" hoofah\n\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt');
    $self->assert_equals('pachoo nachoo "huggery muggery" hoofah', $obj->get_value('gubber'));
}

sub barf_test_get_list_4
{
    my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt', "\ngubber = pachoo nachoo \"huggery muggery\" hoofah\n\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt');
    $self->assert_equals('pachoo nachoo "huggery muggery" hoofah', $obj->get_value('gubber'));
}

# # Not correct to call keyword routines from outside

sub barf_test_block_1
{
    my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt', "\ngubber = pachoo wachoo\n\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt');
    $self->assert_equals('pachoo wachoo', $obj->get_value('gubber'));
}

sub barf_test_block_two_blocks_ok
{
    my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt', "\ngubber = pachoo wachoo\n\n\nrubber = bouncy\n\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt');

    $self->assert_equals('pachoo wachoo', $obj->get_value('gubber'));
    $self->assert_equals('bouncy', $obj->get_single_value('rubber'));
}

# sub test_block_two_blocks_append
# {
#     my $self = shift;
#     Idval::FileString::idv_add_file('/testdir/gt1.txt', "\ngubber = pachoo wachoo\n\n\ngubber += bouncy\n\n");
#     my $obj = Idval::Config->new('/testdir/gt1.txt');
#     print Dumper($obj);
#     $self->assert_deep_equals(['pachoo', 'wachoo', 'bouncy'], $obj->get_value('gubber'));
# }

sub barf_test_block_two_blocks_replace
{
    my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt', "\ngubber = pachoo wachoo\n\n\ngubber = bouncy\n\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt');

    $self->assert_equals('bouncy', $obj->get_value('gubber'));
    $self->assert_equals('bouncy', $obj->get_single_value('gubber'));
}

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

# # sub fast_get_single_value
# # {
# #     my $self = shift;
# #     my $key = shift;
# #     my $selects = shift || [];

# #     $self->fast_merge_blocks($selects);
# #     return ${$self->{VARS}->{$key}}[0];
# # }

# # sub normalize { join ' ', $_[0], $_[1], map{ @{$_} } @{$_[2]}}

# # sub fast_get_single_value_1
# # {
# #     my $self = shift;
# #     my $key = shift;
# #     my $selects = shift || [];

# #     $self->fast_merge_blocks_1($selects);
# #     return ${$self->{VARS}->{$key}}[0];
# # }

# # # Memoization wins; about twice as fast
# # sub test_benchmark_select_1
# # {
# #     my $self = shift;
# #     my %memohash;
# #     my %memohash1;

# #     Idval::FileString::idv_add_file('/testdir/gt1.txt',
# #                                     "\ntype = foo\ngubber = pachoo wachoo\n\n\ntype = boo\ngubber = bouncy\n\n");
# #     my $obj = Idval::Config->new('/testdir/gt1.txt');
# #     my $sel = [['type', '=', 'foo']];

# #     memoize('Idval::Config::_merge_blocks', INSTALL => 'Idval::Config::fast_merge_blocks',
# #             SCALAR_CACHE => [HASH => \%memohash]);

# # #     memoize('Idval::Config::_merge_blocks', INSTALL => 'Idval::Config::fast_merge_blocks_1',
# # #             NORMALIZER => 'normalize',
# # #             SCALAR_CACHE => [HASH => \%memohash1]);

# #     my $save = *Idval::Config::get_single_value;
# #     *Idval::Config::get_single_value = *fast_get_single_value;

# #     my $bm1 = timethis(10000, sub {$obj->get_single_value("gubber", $sel)});
# #     *Idval::Config::get_single_value = $save;
# #     my $bm3 = timethis(10000, sub {$obj->get_single_value("gubber", $sel)});

# #     print STDERR "\nmemo took ", timestr($bm1), "\n";
# #     print STDERR "non-memo took ", timestr($bm3), "\n";
# #     print STDERR "number of keys: ", scalar(keys %memohash), "\n";
# # }

# # # Memoization wins; about twice as fast
# # sub test_benchmark_select_1a
# # {
# #     my $self = shift;
# #     my %memohash1;

# #     Idval::FileString::idv_add_file('/testdir/gt1.txt',
# #                                     "\ntype = foo\ngubber = pachoo wachoo\n\n\ntype = boo\ngubber = bouncy\n\n");
# #     my $obj = Idval::Config->new('/testdir/gt1.txt');
# #     my $sel = [['type', '=', 'foo']];

# # #     memoize('Idval::Config::_merge_blocks', INSTALL => 'Idval::Config::fast_merge_blocks',
# # #             SCALAR_CACHE => [HASH => \%memohash]);

# #     memoize('Idval::Config::_merge_blocks', INSTALL => 'Idval::Config::fast_merge_blocks_1',
# #             NORMALIZER => 'normalize',
# #             SCALAR_CACHE => [HASH => \%memohash1]);

# #     my $save = *Idval::Config::get_single_value;
# #     *Idval::Config::get_single_value = *fast_get_single_value1;
# #     my $bm2 = timethis(10000, sub {$obj->get_single_value("gubber", $sel)});
# #     *Idval::Config::get_single_value = $save;
# #     my $bm3 = timethis(10000, sub {$obj->get_single_value("gubber", $sel)});

# #     print STDERR "memo with custom normalizer took ", timestr($bm3), "\n";
# #     #print STDERR "non-memo took ", timestr($bm2), "\n";
# #     print STDERR "number of keys: ", scalar(keys %memohash), "\n";
# # }

# # # Memoization with a custom normalizer
# # sub test_benchmark_select_2
# # {
# #     my $self = shift;
# #     Idval::FileString::idv_add_file('/testdir/gt1.txt',
# #                                     "\ntype = foo\ngubber = pachoo wachoo\n\n\ntype = boo\ngubber = bouncy\n\n");
# #     my $obj = Idval::Config->new('/testdir/gt1.txt');
# #     my $sel = [['type', '=', 'foo']];

# #     my $bm1 = timethis(100000, sub {$obj->fast_get_single_value_1("gubber", $sel)});
# #     my $bm2 = timethis(100000, sub {$obj->get_single_value("gubber", $sel)});

# #     print STDERR "\nmemo took ", timestr($bm1), "\n";
# #     print STDERR "non-memo took ", timestr($bm2), "\n";
# #     print STDERR "number of keys: ", scalar(keys %Idval::Config::memohash), "\n";
# # }

# # # Memoization wins; about three times as fast
# # sub test_benchmark_select_1a
# # {
# #     my $self = shift;
# #     Idval::FileString::idv_add_file('/testdir/gt1.txt',
# #                                     "\ntype = foo\ngubber = pachoo wachoo\n\n\ntype = boo\ngubber = bouncy\n\n");
# #     my $obj = Idval::Config->new('/testdir/gt1.txt');
# #     my $sel = [['type', '=', 'foo']];
# #     my $bm1 = timethis(30000, sub {$obj->fast_get_single_value("gubber", $sel)});

# #     my ($k, $v) = each(%Idval::Config::memohash);
# #     print STDERR "\nmemo took ", timestr($bm1), "\n";
# #     print STDERR "number of keys: ", scalar(keys %Idval::Config::memohash), "\n";
# #     my $i = 0;
# #     foreach my $key (keys %Idval::Config::memohash)
# #     {
# #         print STDERR "sample hashval: \"$key\" => \"$Idval::Config::memohash{$key}\"\n";

# #         last if $i++ > 3;
# #     }

# #     print STDERR "ref \$k: ", ref $k, " ref $v: ", ref $v, "\n";
# #     print STDERR Dumper($v);
# # }

sub test_block_two_blocks_select_1
{
    my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt',
                                    "{\ntype == foo\ngubber = pachoo wachoo\n}\n{\ntype == boo\ngubber = bouncy}\n");
    $Idval::Config::cfg_dbg = 1;
    my $obj = Idval::Config->new('/testdir/gt1.txt');

    $self->assert_equals('pachoo wachoo', $obj->get_value('gubber', {'type' => 'foo'}));
}

sub barf_test_block_two_blocks_select_1a
{
    my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt',
                                    "{\ntype = foo\ngubber = pachoo wachoo\nhubber=~boo}\n" . 
                                    "type = boo\ngubber = bouncy\n\n");
    $Idval::Config::cfg_dbg = 1;
    my $obj = Idval::Config->new('/testdir/gt1.txt');

    $self->assert_equals('pachoo wachoo', $obj->get_value('gubber', {'type' => 'foo',
                                                                     'hubber' => 'bugaboo'}));
}

# A selector key that isn't in the config block doesn't prevent a match
sub barf_test_block_two_blocks_select_1b
{
    my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt',
                                    "{\ntype = foo\ngubber = pachoo wachoo\nhubber=~boo}\n" . 
                                    "type = boo\ngubber = bouncy\n\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt');

    $self->assert_equals('pachoo wachoo', $obj->get_value('gubber', 
                                                          {'type' => 'foo',
                                                           'whacko' => 'gobble'}));
}

# A selector key that isn't in the config block doesn't prevent a match
# But, a selector key that doesn't match what is in the block fails
sub barf_test_block_two_blocks_select_1c
{
    my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt',
                                    "{\ntype = foo\ngubber = pachoo wachoo\nhubber=~boo}\n" . 
                                    "type = boo\ngubber = bouncy\n\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt');

    $self->assert_equals('', $obj->get_value('gubber', 
                                        {'type' => 'foo',
                                         'hubber' => 'gobble'}));
}

# Test default when it should not be needed (see test_block_two_blocks_select_1)
sub barf_test_block_two_blocks_select_2a
{
    my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt',
                                    "{\ntype = foo\ngubber = pachoo wachoo}\n{\ntype = boo\ngubber = bouncy}\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt');

    $self->assert_equals('pachoo wachoo',
                         $obj->get_value('gubber',
                                         {selects=>{'type' => 'foo'},
                                          default=>'scooby doo'}));
}

# Test default when it should be needed (see test_block_two_blocks_select_1c)
sub barf_test_block_two_blocks_select_2b
{
    my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt',
                                    "{\ntype = foo\ngubber = pachoo wachoo\nhubber=~boo}\n" . 
                                    "type = boo\ngubber = bouncy\n\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt');

    $self->assert_equals('scooby doo',
                         $obj->get_value('gubber', 
                                         {selects=>{'type' => 'foo',
                                                    'hubber' => 'gobble'},
                                          default=>'scooby doo'}));
}


# Block-structured config tests

sub barf_test_block_config1
{
    my $self = shift;
    my $cfg1 =<<EOS;
   type = foo
   gubber = pachoo wachoo
   {
     lubber = boo hoo
     type = woo
   }
EOS

    my $cfg = Idval::Config->new('');
    my ($blocks, $remainder) = $cfg->extract_blocks($cfg1);

    print "Blocks:", Dumper($blocks);
    print "\nremainder: <$remainder>\n";

    $self->assert(qr/^\s*type = foo\s*gubber = pachoo wachoo/,
                  $remainder);

#     Idval::FileString::idv_add_file('/testdir/gt1.txt', $cfg1);
    
#     my $reader = Idval::Config::BlockReader->new(1);

# #     my @list = $reader->extract_blocks($cfg1);
# #     print Dumper(\@list);

# #     my $tree = $reader->parse_blocks("\{$cfg1\}");
# #     print Dumper($tree);

#     my @nodes = $reader->get_blocks($cfg1);
#     #my @nodelist = sort keys %{$nodes};
#     #print "nodelist is: ", join(':', @nodelist), "\n";

#     #print Dumper(\@nodes);
#     # Assert the first (top-level) node
#     # and the second node has that plus "lubber = boo hoo" and "type = woo"
#     $self->assert_equals("gubber = pachoo wachoo\ntype = foo", $nodes[0]);
#     $self->assert_equals("gubber = pachoo wachoo\nlubber = boo hoo\ntype = woo", $nodes[1]);
#     #$self->assert_deep_equals(['=', 'woo'], $nodes->{$nodelist[1]}->{'type'});
}


# sub test_block_config2
# {
#     my $self = shift;
#     my $cfg1 =<<EOS;
#    type = foo
#    gubber = pachoo wachoo
#    {
#      lubber = boo hoo
#      type = woo
#    }
# EOS
#     Idval::FileString::idv_add_file('/testdir/gt1.txt', $cfg1);
    
#     my $obj = Idval::Config->new('/testdir/gt1.txt');
#     $self->assert_equals('pachoo wachoo', $obj->get_value('gubber'));
#     # Should have the same value for the inner block
#     $self->assert_equals('pachoo wachoo', $obj->get_value('gubber', {type => 'woo'}));

#     # type should be 'woo'
#     $self->assert_equals('woo', $obj->get_value('type'));
#     # And also in the inner block
#     $self->assert_equals('boo hoo', $obj->get_value('lubber', {type => 'woo'}));
#     # But not if restricted to the outer level only
#     $self->assert_equals('foo', $obj->get_value('type', {lubber => 'something not boo hoo'}));
# }


# sub test_block_config3
# {
#     my $self = shift;

#     Idval::FileString::idv_add_file('/testdir/gt1.txt', "\nplugin_dir = /testdir/Idval\n" .
#                                     "{\ncommand_name = tag_write4\nweight = 300\n}\n");
    
#     my $obj = Idval::Config->new('/testdir/gt1.txt');
#     # weight should be 300 for inner block
#     $self->assert_equals(300, $obj->get_value('weight', {'command_name' => 'tag_write4'}));

#     # but weight should have no value for a different command name
#     $self->assert_equals('', $obj->get_value('weight', {'command_name' => 'goober'}));
# }










# sub test_block_two_blocks_select_2
# {
#     my $self = shift;
#     Idval::FileString::idv_add_file('/testdir/gt1.txt',
#                                     "\ntype =~ foo.*\ngubber = pachoo wachoo\n\n\ntype = boo\ngubber = bouncy\n\n");
#     my $obj = Idval::Config->new('/testdir/gt1.txt');

#     $self->assert_deep_equals(['pachoo', 'wachoo'], $obj->get_value('gubber', [['type', '=', 'foobar']]));
# }

# # sub test_other_keywords_1
# # {
# #     my $self = shift;
# #     Idval::FileString::idv_add_file('/testdir/gt1.txt', "\ntype = foo\nTAGNAME TYPE = CLASS\n\n");
# #     my $obj = Idval::Config->new('/testdir/gt1.txt');

# #     $self->assert_deep_equals([['TYPE', '=', 'CLASS']], $obj->get_keyword_value('TAGNAME', [['type', '=', 'foo']]));
# # }

# # sub test_other_keywords_2
# # {
# #     my $self = shift;
# #     Idval::FileString::idv_add_file('/testdir/gt1.txt', "\ntype = foo\nVALUE ALBUM =~ /^foo/\n\n");
# #     my $obj = Idval::Config->new('/testdir/gt1.txt');

# #     $self->assert_deep_equals([['ALBUM', '=~', '/^foo/']], $obj->get_keyword_value('VALUE', [['type', '=', 'foo']]));
# # }

# sub test_two_files_1
# {
#     my $self = shift;
#     Idval::FileString::idv_add_file('/testdir/gt1.txt', "\ngubber = pachoo wachoo\n\n");
#     Idval::FileString::idv_add_file('/testdir/gt2.txt', "\nrubber = bouncy\n\n");
#     my $obj = Idval::Config->new('/testdir/gt1.txt');
#     $obj->add_file('/testdir/gt2.txt');

#     $self->assert_deep_equals(['pachoo', 'wachoo'], $obj->get_value('gubber'));
#     $self->assert_equals('bouncy', $obj->get_single_value('rubber'));
# }

# sub test_magic_word_1
# {
#     my $self = shift;
#     Idval::FileString::idv_add_file('/testdir/gt1.txt', "\ngubber = {DATA}/pachoo wachoo/{DATA}/boo\n\n");
#     my $datadir = Idval::Common::get_top_dir('data');
#     my $obj = Idval::Config->new('/testdir/gt1.txt');
#     $self->assert_deep_equals(["$datadir/pachoo", "wachoo/$datadir/boo"], $obj->get_value('gubber'));
# }

# sub test_eval_1
# {
#     my $self = shift;
#     Idval::FileString::idv_add_file('/testdir/gt1.txt', "\ngubber = pachoo\r\n\rhubber=4\n\n");
#     my $obj = Idval::Config->new('/testdir/gt1.txt');
#     my $block = ${$obj->{BLOCKS}}[0];

#     my $retval = $block->evaluate({'gubber' => 'pachoo'});
#     $self->assert_num_equals(1, $retval);

#     $retval = $block->evaluate({'gubber' => 'gacko'});
#     $self->assert_num_equals(0, $retval);

#     $retval = $block->evaluate({'gubber' => 'pachoo',
#                                    'hubber' => 4});
#     $self->assert_num_equals(1, $retval);

#     $retval = $block->evaluate({'gubber' => 'pachoo',
#                                    'hubber' => 3});
#     $self->assert_num_equals(0, $retval);

#     $retval = $block->evaluate({'gubber' => 'gacko'});
#     $self->assert_num_equals(0, $retval);

#     $retval = $block->evaluate({'hubber' => 3});
#     $self->assert_num_equals(0, $retval);

# #     $retval = $block->evaluate([['gubber', '=~', 'p[aeiou]choo']]);
# #     $self->assert_num_equals(1, $retval);

# #     $retval = $block->evaluate([['gubber', 'has', 'choo']]);
# #     $self->assert_num_equals(1, $retval);

# }

# sub test_eval_2
# {
#     my $self = shift;
#     Idval::FileString::idv_add_file('/testdir/gt1.txt', "\ngubber has pachoo\r\n\rhubber=4\n\n");
#     my $obj = Idval::Config->new('/testdir/gt1.txt');
#     my $block = ${$obj->{BLOCKS}}[0];

#     my $retval = $block->evaluate([['gubber', '=', 'pachoo'], ['hubber', '=', 4]]);
#     $self->assert_num_equals(1, $retval);

#     $retval = $block->evaluate([['gubber', '=', 'pachoo'], ['hubber', '=', 3]]);
#     $self->assert_num_equals(0, $retval);

# }

# # Check behavior with select keys that don't exist in config block
# sub test_eval_3a
# {
#     my $self = shift;
#     Idval::FileString::idv_add_file('/testdir/gt1.txt', "\ngubber = pachoo\r\n\rhubber=4\n\n");
#     my $obj = Idval::Config->new('/testdir/gt1.txt', Idval::Config::STRICT_MATCH);

#     $self->assert_null($obj->get_single_value('gubber', [['gubber', '=', 'nope'], ['blubber', '=', 4]]));
#     $self->assert_null($obj->get_single_value('hubber', [['gubber', '=', 'nope'], ['blubber', '=', 4]]));
# }

# # Check behavior with select keys that don't exist in config block
# sub test_eval_3b
# {
#     my $self = shift;
#     Idval::FileString::idv_add_file('/testdir/gt1.txt', "\ngubber = pachoo\r\n\rhubber=4\n\n");
#     # Allow selectors to have keys that don't appear in the data.
#     my $obj = Idval::Config->new('/testdir/gt1.txt', Idval::Config::LOOSE_MATCH);
#     my $test_sel1 = [['gubber', '=', 'nope'], ['blubber', '=', 4]];
#     my $test_sel2 = [['gubber', '=', 'pachoo'], ['blubber', '=', 4]];

#     # Selector that is present does not match
#     $self->assert_null($obj->get_single_value('gubber', $test_sel1));
#     $self->assert_null($obj->get_single_value('hubber', $test_sel1));

#     # Selector that is present does match
#     $self->assert_equals('pachoo', $obj->get_single_value('gubber', $test_sel2));
#     $self->assert_equals(4, $obj->get_single_value('hubber', $test_sel2));
# }

# # Check behavior with duplicate select keys
# sub test_eval_4
# {
#     my $self = shift;
#     Idval::FileString::idv_add_file('/testdir/gt1.txt', "\ngubber = pachoo\r\n\rhubber=4\n\n");
#     my $obj = Idval::Config->new('/testdir/gt1.txt');
#     my $block = ${$obj->{BLOCKS}}[0];

#     my $retval = $block->evaluate([['gubber', '=', 'frizzle'], ['gubber', '=', 'pachoo']]);
#     $self->assert_num_equals(1, $retval);

#     $retval = $block->evaluate([['gubber', '=', 'frizzle'], ['gubber', '=', 'gizzard']]);
#     $self->assert_num_equals(0, $retval);

# }

# # Check behavior with a hash ref as a selector
# sub test_eval_5
# {
#     my $self = shift;
#     Idval::FileString::idv_add_file('/testdir/gt1.txt', "\ngubber = pachoo\r\n\rhubber=4\n\n");
#     my $obj = Idval::Config->new('/testdir/gt1.txt');
#     my $block = ${$obj->{BLOCKS}}[0];
#     my %record = ('hubber' => 4,
#                   'gubber' => 'pachoo');

#     my $retval = $block->evaluate(\%record);
#     $self->assert_num_equals(1, $retval);

#     $record{'gubber'} = 'gizzard';
#     $retval = $block->evaluate(\%record);
#     $self->assert_num_equals(0, $retval);

# }

1;
