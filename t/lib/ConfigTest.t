package Idval::Config::Test;
use strict;
use warnings;
use lib qw{t/lib};

use base qw(Test::Class);
use Test::More;

use Data::Dumper;
#use Memoize;

use Idval::Config;
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

sub get : Tests
{
    Idval::FileString::idv_add_file('/testdir/gt1.txt', "{\ngubber = 3\nhubber=4\n}\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt');
    # Since the block has no selects, we can pass in any selectors and it should succeed
    is($obj->get_single_value('gubber', {foo => 'boo'}), 3);

    return;
}

sub get_with_selectors : Test(2)
{
    Idval::FileString::idv_add_file('/testdir/gt1.txt', "{\nfoo == boo\ngubber = 3\nhubber=4\n}\n");
    #print "\n\n*** test_get_with_selectors ***\n\n";
    my $obj = Idval::Config->new('/testdir/gt1.txt');
    # Since the block has no selects, we can pass in any selectors and it should succeed
    is($obj->get_single_value('gubber', {foo => 'boo'}), 3);
    is($obj->get_single_value('hubber', {foo => 'boo'}), 4);

    return;
}

sub get_with_extra_CR : Test(2)
{
    Idval::FileString::idv_add_file('/testdir/gt1.txt', "{\ngubber = pachoo\r\n\rhubber=4\n}\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt');
    # Since the block has no selects, we can pass in any selectors and it should succeed
    is($obj->get_single_value('gubber', {foo => 'boo'}), 'pachoo');
    is($obj->get_single_value('hubber', {foo => 'boo'}), 4);

    return;
}

# Test that we get the default default
sub no_matching_keys_and_no_default_should_return_nothing : Test(1)
{
    #my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt', "{\ngubber = 3\nhubber=4\n}\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt');
    # Since the block has no selects, we can pass in any selectors and it should succeed
    is($obj->get_single_value('flubber', {foo => 'boo'}), '');

    return;
}

sub no_matching_keys_and_a_default_should_return_default : Test(1)
{
    #my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt', "{\ngubber = 3\nhubber=4\n}\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt');
    is($obj->get_single_value('flubber', {}, 18), 18);

    return;
}

sub get_value_with_embedded_quotes : Test(1)
{
    #my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt', "{\ngubber = pachoo nachoo \"huggery muggery\" hoofah\n}\n");
    # Since the block has no selects, we can pass in any selectors and it should succeed
    my $obj = Idval::Config->new('/testdir/gt1.txt');
    is($obj->get_value('gubber', {foo => 'boo'}), 'pachoo nachoo "huggery muggery" hoofah');

    return;
}

sub get_list : Test(2)
{
    #my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt', "{\ngubber = 3\nhubber = 2\nhubber += 4\nhubber += 5\n}\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt');
    # Since the block has no selects, we can pass in any selectors and it should succeed
    my $vars = $obj->merge_blocks({foo => 'boo'});
    #print "result of merge_blocks {foo => 'boo'} is: ", Dumper($vars);
    is($obj->get_single_value('gubber', {foo => 'boo'}), 3);
    is_deeply([2, 4, 5], $obj->get_value('hubber', {foo => 'boo'}));

    return;
}

sub block_get : Test(1)
{
    #my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt',
                                    "{\ntype == foo\ngubber = pachoo wachoo\n}\n{\ntype == boo\ngubber = bouncy\n}\n");
    #my $cfg_dbg = 1;
    my $cfg_dbg = 0;
    my $obj = Idval::Config->new('/testdir/gt1.txt', $cfg_dbg);

    is($obj->get_value('gubber', {'type' => 'foo'}), 'pachoo wachoo');

    return;

}

sub block_get_from_second_block : Test(1)
{
    #my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt',
                                    "{\ntype == foo\ngubber = pachoo wachoo\n}\n{\ntype == boo\ngubber = bouncy\n}\n");
    my $cfg_dbg = 0;
    my $obj = Idval::Config->new('/testdir/gt1.txt', $cfg_dbg);

    is($obj->get_value('gubber', {'type' => 'boo'}), 'bouncy');

    return;

}

sub block_get_no_matches_should_return_default : Test(1)
{
    #my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt',
                                    "{\ntype == foo\ngubber = pachoo wachoo\n}\n{\ntype == boo\ngubber = bouncy\n}\n");
    my $cfg_dbg = 0;
    my $obj = Idval::Config->new('/testdir/gt1.txt', $cfg_dbg);

    is($obj->get_value('gubber', {'type' => 'blargle'}, 'hubba'), 'hubba');

    return;

}

sub block_get_two_matches_should_return_last : Test(1)
{
    #my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt',
                                    "{\ntype == foo\ngubber = pachoo wachoo\n}\n{\ntype == foo\ngubber = bouncy\n}\n");
    my $cfg_dbg = 0;
    my $obj = Idval::Config->new('/testdir/gt1.txt', $cfg_dbg);

    is($obj->get_value('gubber', {'type' => 'foo'}, 'hubba'), 'bouncy');

    return;

}

sub block_get_with_two_selects : Test(1)
{
    #my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt',
                                    "{\ntype == foo\nmarley == tuff\ngubber = pachoo wachoo\n}\n{\ntype == boo\nmarley == tuff\ngubber = bouncy\n}\n");
    my $cfg_dbg = 0;
    my $obj = Idval::Config->new('/testdir/gt1.txt', $cfg_dbg);

    is($obj->get_value('gubber', {'type' => 'foo', 'marley' => 'tuff'}), 'pachoo wachoo');

    return;

}

# # An append should replace an assignment in the same block
# sub test_get_list_2
# {
#     #my $self = shift;
#     Idval::FileString::idv_add_file('/testdir/gt1.txt', "\ngubber = pachoo\ngubber += wachoo\n\n");
#     my $obj = Idval::Config->new('/testdir/gt1.txt');
#     is_deeply(['wachoo'], $obj->get_value('gubber'));
# }

# # An append by itself should append to nothing
# sub test_get_list_2a
# {
#     #my $self = shift;
#     Idval::FileString::idv_add_file('/testdir/gt1.txt', "\ngubber += wachoo\n\n");
#     my $obj = Idval::Config->new('/testdir/gt1.txt');
#     is_deeply(['wachoo'], $obj->get_value('gubber'));
# }

# # An append after something other than an assignment should replace
# sub test_get_list_2b
# {
#     #my $self = shift;
#     Idval::FileString::idv_add_file('/testdir/gt1.txt', "\ngubber =~ pachoo\ngubber += wachoo\n\n");
#     my $obj = Idval::Config->new('/testdir/gt1.txt');
#     is_deeply(['wachoo'], $obj->get_value('gubber'));
# }

sub barf_test_get_list_4
{
    #my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt', "\ngubber = pachoo nachoo \"huggery muggery\" hoofah\n\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt');
    is($obj->get_value('gubber'), 'pachoo nachoo "huggery muggery" hoofah');

    return;
}

# # Not correct to call keyword routines from outside

sub barf_test_block_1
{
    #my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt', "\ngubber = pachoo wachoo\n\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt');
    is($obj->get_value('gubber'), 'pachoo wachoo');

    return;
}

sub barf_test_block_two_blocks_ok
{
    #my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt', "\ngubber = pachoo wachoo\n\n\nrubber = bouncy\n\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt');

    is($obj->get_value('gubber'), 'pachoo wachoo');
    is($obj->get_single_value('rubber'), 'bouncy');

    return;
}

# sub test_block_two_blocks_append
# {
#     #my $self = shift;
#     Idval::FileString::idv_add_file('/testdir/gt1.txt', "\ngubber = pachoo wachoo\n\n\ngubber += bouncy\n\n");
#     my $obj = Idval::Config->new('/testdir/gt1.txt');
#     print Dumper($obj);
#     is_deeply(['pachoo', 'wachoo', 'bouncy'], $obj->get_value('gubber'));
# }

sub barf_test_block_two_blocks_replace
{
    #my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt', "\ngubber = pachoo wachoo\n\n\ngubber = bouncy\n\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt');

    is($obj->get_value('gubber'), 'bouncy');
    is($obj->get_single_value('gubber'), 'bouncy');

    return;
}

# # # Memoization wins; about twice as fast
# # sub test_benchmark_select_1
# # {
# #     #my $self = shift;
# #     my $data = "\nSELECT type = foo\ngubber = pachoo wachoo\n\n\nSELECT type = boo\ngubber = bouncy\n\n";
# #     my $obj = Idval::Config->new(\$data);

# #     my $bm1 = timethis(300000, sub {$obj->get_value("gubber", {"type" => "foo"})});
# #     my $bm2 = timethis(300000, sub {$obj->get_value_memo("gubber", {"type" => "foo"})});

# #     print STDERR "non-memo took ", timestr($bm1), "\n";
# #     print STDERR "memo took ", timestr($bm2), "\n";
# # }

# # sub fast_get_single_value
# # {
# #     #my $self = shift;
# #     my $key = shift;
# #     my $selects = shift || [];

# #     $self->fast_merge_blocks($selects);
# #     return ${$self->{VARS}->{$key}}[0];
# # }

# # sub normalize { join ' ', $_[0], $_[1], map{ @{$_} } @{$_[2]}}

# # sub fast_get_single_value_1
# # {
# #     #my $self = shift;
# #     my $key = shift;
# #     my $selects = shift || [];

# #     $self->fast_merge_blocks_1($selects);
# #     return ${$self->{VARS}->{$key}}[0];
# # }

# # # Memoization wins; about twice as fast
# # sub test_benchmark_select_1
# # {
# #     #my $self = shift;
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
# #     #my $self = shift;
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
# #     #my $self = shift;
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
# #     #my $self = shift;
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

sub block_two_blocks_select_1 : Test(1)
{
    #my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt',
                                    "{\ntype == foo\ngubber = pachoo wachoo\n}\n{\ntype == boo\ngubber = bouncy\n}\n");
    my $cfg_dbg = 0;
    my $obj = Idval::Config->new('/testdir/gt1.txt', $cfg_dbg);

    is($obj->get_value('gubber', {'type' => 'foo'}), 'pachoo wachoo');

    return;
}

sub barf_test_block_two_blocks_select_1a
{
    #my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt',
                                    "{\ntype = foo\ngubber = pachoo wachoo\nhubber=~boo\n}\n" .
                                    "type = boo\ngubber = bouncy\n\n");
    #$Idval::Config::cfg_dbg = 1;
    my $obj = Idval::Config->new('/testdir/gt1.txt');

    is($obj->get_value('gubber', {'type' => 'foo', 'hubber' => 'bugaboo'}), 'pachoo wachoo');

    return;
}

# A selector key that isn't in the config block doesn't prevent a match
sub barf_test_block_two_blocks_select_1b
{
    #my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt',
                                    "{\ntype = foo\ngubber = pachoo wachoo\nhubber=~boo\n}\n" .
                                    "type = boo\ngubber = bouncy\n\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt');

    is($obj->get_value('gubber', {'type' => 'foo',
                                  'whacko' => 'gobble'}), 'pachoo wachoo');

    return;
}

# A selector key that isn't in the config block doesn't prevent a match
# But, a selector key that doesn't match what is in the block fails
sub barf_test_block_two_blocks_select_1c
{
    #my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt',
                                    "{\ntype = foo\ngubber = pachoo wachoo\nhubber=~boo\n}\n" .
                                    "type = boo\ngubber = bouncy\n\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt');

    is($obj->get_value('gubber', {'type' => 'foo',
                                  'hubber' => 'gobble'}), '');

    return;
}

# Test default when it should not be needed (see test_block_two_blocks_select_1)
sub barf_test_block_two_blocks_select_2a
{
    #my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt',
                                    "{\ntype = foo\ngubber = pachoo wachoo\n}\n{\ntype = boo\ngubber = bouncy\n}\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt');

    is($obj->get_value('gubber', {selects=>{'type' => 'foo'},
                                  default=>'scooby doo'}), 'pachoo wachoo');

    return;
}

# Test default when it should be needed (see test_block_two_blocks_select_1c)
sub barf_test_block_two_blocks_select_2b
{
    #my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt',
                                    "{\ntype = foo\ngubber = pachoo wachoo\nhubber=~boo\n}\n" .
                                    "type = boo\ngubber = bouncy\n\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt');

    is($obj->get_value('gubber', {selects=>{'type' => 'foo',
                                            'hubber' => 'gobble'},
                                  default=>'scooby doo'}), 'scooby doo');

    return;
}

sub multiple_select_key_when_one_key_should_match : Test(1)
{
    #my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt',
                                    "{\ntype == foo\ngubber = pachoo wachoo\n}\n{\ntype == boo\ngubber = bouncy\n}\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt');

    is($obj->get_value('gubber', {'type' => ['awfu', 'big', 'foo']},
                       'scooby doo'), 'pachoo wachoo');

    return;
}

sub multiple_select_key_when_no_keys_should_match : Test(1)
{
    #my $self = shift;
    Idval::FileString::idv_add_file('/testdir/gt1.txt',
                                    "{\ntype == foo\ngubber = pachoo wachoo\n}\n{\ntype == boo\ngubber = bouncy\n}\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt');

    is($obj->get_value('gubber', {'type' => ['awfu', 'big', 'mess']},
                       'scooby doo'), 'scooby doo');

    return;
}


# Block-structured config tests

sub barf_test_block_config1
{
    #my $self = shift;
    my $cfg1 =<<"EOS";
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

    ok(qr/^\s*type = foo\s*gubber = pachoo wachoo/,
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
#     is($nodes[0], "gubber = pachoo wachoo\ntype = foo");
#     is($nodes[1], "gubber = pachoo wachoo\nlubber = boo hoo\ntype = woo");
#     #is_deeply(['=', 'woo'], $nodes->{$nodelist[1]}->{'type'});

    return;
}


# sub test_block_config2
# {
#     #my $self = shift;
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
#     is($obj->get_value('gubber'), 'pachoo wachoo');
#     # Should have the same value for the inner block
#     is($obj->get_value('gubber', {type => 'woo'}), 'pachoo wachoo');

#     # type should be 'woo'
#     is($obj->get_value('type'), 'woo');
#     # And also in the inner block
#     is($obj->get_value('lubber', {type => 'woo'}), 'boo hoo');
#     # But not if restricted to the outer level only
#     is($obj->get_value('type', {lubber => 'something not boo hoo'}), 'foo');
# }


# sub test_block_config3
# {
#     #my $self = shift;

#     Idval::FileString::idv_add_file('/testdir/gt1.txt', "\nplugin_dir = /testdir/Idval\n" .
#                                     "{\ncommand_name = tag_write4\nweight = 300\n}\n");

#     my $obj = Idval::Config->new('/testdir/gt1.txt');
#     # weight should be 300 for inner block
#     is($obj->get_value('weight', {'command_name' => 'tag_write4'}), 300);

#     # but weight should have no value for a different command name
#     is($obj->get_value('weight', {'command_name' => 'goober'}), '');
# }










# sub test_block_two_blocks_select_2
# {
#     #my $self = shift;
#     Idval::FileString::idv_add_file('/testdir/gt1.txt',
#                                     "\ntype =~ foo.*\ngubber = pachoo wachoo\n\n\ntype = boo\ngubber = bouncy\n\n");
#     my $obj = Idval::Config->new('/testdir/gt1.txt');

#     is_deeply(['pachoo', 'wachoo'], $obj->get_value('gubber', [['type', '=', 'foobar']]));
# }

# # sub test_other_keywords_1
# # {
# #     #my $self = shift;
# #     Idval::FileString::idv_add_file('/testdir/gt1.txt', "\ntype = foo\nTAGNAME TYPE = CLASS\n\n");
# #     my $obj = Idval::Config->new('/testdir/gt1.txt');

# #     is_deeply([['TYPE', '=', 'CLASS']], $obj->get_keyword_value('TAGNAME', [['type', '=', 'foo']]));
# # }

# # sub test_other_keywords_2
# # {
# #     #my $self = shift;
# #     Idval::FileString::idv_add_file('/testdir/gt1.txt', "\ntype = foo\nVALUE ALBUM =~ /^foo/\n\n");
# #     my $obj = Idval::Config->new('/testdir/gt1.txt');

# #     is_deeply([['ALBUM', '=~', '/^foo/']], $obj->get_keyword_value('VALUE', [['type', '=', 'foo']]));
# # }

# sub test_two_files_1
# {
#     #my $self = shift;
#     Idval::FileString::idv_add_file('/testdir/gt1.txt', "\ngubber = pachoo wachoo\n\n");
#     Idval::FileString::idv_add_file('/testdir/gt2.txt', "\nrubber = bouncy\n\n");
#     my $obj = Idval::Config->new('/testdir/gt1.txt');
#     $obj->add_file('/testdir/gt2.txt');

#     is_deeply(['pachoo', 'wachoo'], $obj->get_value('gubber'));
#     is($obj->get_single_value('rubber'), 'bouncy');
# }

# sub test_magic_word_1
# {
#     #my $self = shift;
#     Idval::FileString::idv_add_file('/testdir/gt1.txt', "\ngubber = {DATA}/pachoo wachoo/{DATA}/boo\n\n");
#     my $datadir = Idval::Common::get_top_dir('data');
#     my $obj = Idval::Config->new('/testdir/gt1.txt');
#     is_deeply(["$datadir/pachoo", "wachoo/$datadir/boo"], $obj->get_value('gubber'));
# }

# sub test_eval_1
# {
#     #my $self = shift;
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
#     #my $self = shift;
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
#     #my $self = shift;
#     Idval::FileString::idv_add_file('/testdir/gt1.txt', "\ngubber = pachoo\r\n\rhubber=4\n\n");
#     my $obj = Idval::Config->new('/testdir/gt1.txt', Idval::Config::STRICT_MATCH);

#     $self->assert_null($obj->get_single_value('gubber', [['gubber', '=', 'nope'], ['blubber', '=', 4]]));
#     $self->assert_null($obj->get_single_value('hubber', [['gubber', '=', 'nope'], ['blubber', '=', 4]]));
# }

# # Check behavior with select keys that don't exist in config block
# sub test_eval_3b
# {
#     #my $self = shift;
#     Idval::FileString::idv_add_file('/testdir/gt1.txt', "\ngubber = pachoo\r\n\rhubber=4\n\n");
#     # Allow selectors to have keys that don't appear in the data.
#     my $obj = Idval::Config->new('/testdir/gt1.txt', Idval::Config::LOOSE_MATCH);
#     my $test_sel1 = [['gubber', '=', 'nope'], ['blubber', '=', 4]];
#     my $test_sel2 = [['gubber', '=', 'pachoo'], ['blubber', '=', 4]];

#     # Selector that is present does not match
#     $self->assert_null($obj->get_single_value('gubber', $test_sel1));
#     $self->assert_null($obj->get_single_value('hubber', $test_sel1));

#     # Selector that is present does match
#     is($obj->get_single_value('gubber', $test_sel2), 'pachoo');
#     is($obj->get_single_value('hubber', $test_sel2), 4);
# }

# # Check behavior with duplicate select keys
# sub test_eval_4
# {
#     #my $self = shift;
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
#     #my $self = shift;
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

sub merge_one_block : Test(1)
{
    #my $self = shift;

    my $cfg_file =<<EOF;
    {
        # Collect settings of use only to overall Idval configuration
        config_group == idval_settings

            plugin_dir = %DATA%/Plugins
            command_dir = %DATA%/commands
            command_extension = pm
            data_store   = %DATA%/data_store.bin
            demo_validate_cfg = %DATA%/val_demo.cfg

            visible_separator = %%
    }

    {
        command_name == lame
            command_path = ~/local/bin/lame.exe
    }

    {
        command_name == tag
            command_path = ~/local/bin/Tag.exe
    }
EOF
    my $datadir = Idval::Common::get_top_dir('Data');
    my $result = {
        'command_extension' => 'pm',
                'demo_validate_cfg' => "$datadir/val_demo.cfg",
        'command_dir' => "$datadir/commands",
        'plugin_dir' => "$datadir/Plugins",
        'data_store' => "$datadir/data_store.bin",
        'visible_separator' => '%%'
    };
    Idval::FileString::idv_add_file('/testdir/gt1.txt', $cfg_file);
    my $obj = Idval::Config->new('/testdir/gt1.txt');

    my $vars = $obj->merge_blocks({'config_group' => 'idval_settings'});

    # Should be just 'plugin_dir through 'visible_separator'
    #print "result of merge blocks with \{'config_group' => 'idval_settings'\}: ", Dumper($vars);
    is_deeply($vars, $result);
}

sub get_one_value : Test(1)
{
    #my $self = shift;

    Idval::FileString::idv_add_file('/testdir/gt1.txt',
                                    "{\ntype == foo\ngubber = pachoo wachoo\n}\n{\ntype == boo\ngubber = bouncy\n}\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt');

    my $val = $obj->get_value('gubber', {'type' => 'boo'});

    is($val, 'bouncy');
    #print "val is: \"$val\"\n"; # should be 'bouncy'
}

sub get_value_using_two_selectors : Test(1)
{
    #my $self = shift;

    Idval::FileString::idv_add_file('/testdir/gt1.txt',
                                    "{\ntype == foo\nmarley == tuff\ngubber = pachoo wachoo\n}\n{\ntype == boo\nmarley == tuff\ngubber = bouncy\n}\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt');
    my $val = $obj->get_value('gubber', {'type' => 'foo', 'marley' => 'tuff'});
    #print "Result for \{'type' => 'foo', 'marley' => 'tuff'\}: ", Dumper($val); # Should be 'pachoo wachoo'
    is($val, 'pachoo wachoo');
}

sub get_value_using_selector_list : Test(1)
{
    #my $self = shift;

    Idval::FileString::idv_add_file('/testdir/gt1.txt',
                                    "{\ntype == foo\ngubber = pachoo wachoo\n}\n" .
                                    "{\ntype == boo\ngubber = bouncy\n}\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt');

    my $val = $obj->get_value('gubber',
                              {'type' => ['awfu', 'big', 'foo']},
                              'scooby doo');

    #print "Result for : {'type' => ['awfu', 'big', 'foo']}", Dumper($val); #  Should be 'pachoo wachoo'
    is($val, 'pachoo wachoo');
}

sub get_values_including_sub_block : Test(1)
{
    #my $self = shift;

    my $cfg_file =<<EOF;
    {
    # Collect settings of use only to overall Idval configuration
    config_group == idval_settings

    plugin_dir = %DATA%/Plugins
    command_dir = %DATA%/commands
    command_extension = pm
    data_store   = %DATA%/data_store.bin
    demo_validate_cfg = %DATA%/val_demo.cfg

    visible_separator = %%
    }

    {
    command_name == lame
    command_path = ~/local/bin/lame.exe
    }

    {
    command_name == tag
    command_path = ~/local/bin/Tag.exe
    }

    {
    command_name == timidity
    command_path = /cygdrive/c/Program Files/Timidity++ Project/Timidity++/timidity.exe
    config_file = /cygdrive/h/local/share/freepats/crude.cfg
    }

    {
        # Set up default conversions (any MUSIC file should be converted to .mp3)
        class        == MUSIC
        convert      = MP3
    {
        type        == ABC
        convert      = MIDI
    }
    }

    {
        config_group == tag_mappings

        # Always have this
        GUBBER = HUBBER

    {
        type == ABC

        T = TITLE
        C = TCOM
        D = TALB
        A = TEXT
        K = TKEY
        Z = TENC
        X = TRACK
        abc-copyright = TCOP
    }

    {
        type == OGG

        TRACKNUMBER = TRACK
        DATE == YEAR
    }

    }
EOF
    my $result = {
          'A' => 'TEXT',
          'GUBBER' => 'HUBBER',
          'T' => 'TITLE',
          'abc-copyright' => 'TCOP',
          'X' => 'TRACK',
          'K' => 'TKEY',
          'Z' => 'TENC',
          'D' => 'TALB',
          'C' => 'TCOM'
        };

    Idval::FileString::idv_add_file('/testdir/gt1.txt', $cfg_file);
    my $obj = Idval::Config->new('/testdir/gt1.txt');

    #print "new config: ", Dumper($obj);
    my $vars = $obj->merge_blocks({'config_group' => 'tag_mappings',
                                   'type' => 'ABC'
                                  });

    # Should be just 'T' through 'abc-copyright', plus GUBBER
    #print "result of merge blocks with \{'config_group' => 'tag_mappings', 'type' => 'ABC'\}: ",
    #Dumper($vars);

    is_deeply($vars, $result);
    
}

# Can we back-add inherited values?
# Nope! This masking behavior allows overrides
sub no_back_adding_of_inherited_values : Test(1)
{
    #my $self = shift;

    my $cfg_file =<<EOF;
    {
        # Set up default conversions (any MUSIC file should be converted to .mp3)
        class        == MUSIC
        convert      = MP3
        {
            type        == ABC
            convert      = MIDI
        }
    }
    
    {
        config_group == tag_mappings

        # Always have this
        GUBBER = HUBBER

    {
        type == ABC

        T = TITLE
        C = TCOM
        D = TALB
        A = TEXT
        K = TKEY
        Z = TENC
        X = TRACK
        abc-copyright = TCOP
    }

    {
        type == OGG

        TRACKNUMBER = TRACK
        DATE == YEAR
    }

    }

    {
        class == MUSIC
        convert = OGG
        fuffer = nutter
    }

EOF

    my $result = {
        'convert' => 'OGG',
        'fuffer' => 'nutter'
    };
    Idval::FileString::idv_add_file('/testdir/gt1.txt', $cfg_file);
    my $obj = Idval::Config->new('/testdir/gt1.txt');

    #print "new config: ", Dumper($obj);
    my $vars = $obj->merge_blocks({'class' => 'MUSIC',
                                   'type' => 'ABC'
                                  });

    # Should be just 'T' through 'abc-copyright', plus GUBBER
    #print "result of merge blocks with \{'class' => 'MUSIC', 'type' => 'ABC'\}: ", Dumper($vars);

    is_deeply($vars, $result);
}

# Can we back-add other values?
# Yep!
sub no_back_adding_of_other_values : Test(1)
{
    #my $self = shift;

my $cfg_file =<<EOF;
    {
        # Set up default conversions (any MUSIC file should be converted to .mp3)
        class        == MUSIC
        convert      = MP3
        {
            type        == ABC
            convert      = MIDI
        }
    }

    {
        config_group == tag_mappings

        # Always have this
        GUBBER = HUBBER

        {
        type == ABC

        T = TITLE
        C = TCOM
        D = TALB
        A = TEXT
        K = TKEY
        Z = TENC
        X = TRACK
        abc-copyright = TCOP
        }

        {
        type == OGG

        TRACKNUMBER = TRACK
        DATE == YEAR
        }

    }

    {
    class == MUSIC
    fuffer = nutter
    }

EOF
    my $result = {
          'convert' => 'MIDI',
          'fuffer' => 'nutter'
    };
    Idval::FileString::idv_add_file('/testdir/gt1.txt', $cfg_file);
    my $obj = Idval::Config->new('/testdir/gt1.txt');

    #print "new config: ", Dumper($obj);
    my $vars = $obj->merge_blocks({'class' => 'MUSIC',
                                   'type' => 'ABC'
                                  });

    # Should be just 'T' through 'abc-copyright', plus GUBBER
    #print "result of merge blocks with \{'class' => 'MUSIC', 'type' => 'ABC'\}: ", Dumper($vars);

    is_deeply($vars, $result);
}

# Config can handle strings containing config data as well as file names
sub get_immediate : Test(1)
{
    #my $self = shift;
    my $obj = Idval::Config->new("{\ngubber = 3\nhubber=4\n}\n");
    # Since the block has no selects, we can pass in any selectors and it should succeed
    is($obj->get_single_value('gubber', {foo => 'boo'}), 3);
    #is($obj->get_single_value('hubber', {foo => 'boo'}), 4);

    return;
}

1;
