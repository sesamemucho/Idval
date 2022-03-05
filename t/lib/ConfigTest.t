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

sub brackets_must_be_on_separate_lines : Test(2)
{
    my $obj;
    my $eval_status;
    my $str_buf;

    open(my $fh, '>', \$str_buf) or die "Can't redirect NOWHERE: $!";
    my $old_settings = Idval::Logger::get_settings();
    Idval::Logger::re_init({log_out => $fh, debugmask=>'nobody'});
    eval {$obj = Idval::Config->new("{gubber == 33\ngubber == 34\n\nfoo = 1\n}\n");};
    $eval_status = $@ if $@;
    like($eval_status, qr/Any '{' or '}' must be on a line by itself/);

    eval {$obj = Idval::Config->new("{\nbubber == 33\ngubber == 34\n\nfoo = 1}\n");};
    $eval_status = $@ if $@;
    like($eval_status, qr/Any '{' or '}' must be on a line by itself/);
    Idval::Logger::re_init($old_settings);
    return;
}

sub merge_blocks1 : Test(1)
{
    my $obj;
    my $str_buf;

    open(my $fh, '>', \$str_buf) or die "Can't redirect NOWHERE: $!";
    my $old_settings = Idval::Logger::get_settings();
    Idval::Logger::re_init({log_out => $fh, debugmask=>'nobody'});
    eval {$obj = Idval::Config->new("{\ngubber == 33\ngubber == 34\n\nfoo = 1\n}\n");};
    my $eval_status = $@ if $@;

    like($eval_status, qr/Conditional variable \"gubber\" was already used in this block/);
    Idval::Logger::re_init($old_settings);
    return;
}

sub merge_blocks2 : Test(3)
{
    my $obj = Idval::Config->new("{\ngubber == 33\n\nfoo = 1\n}\n");
    # Since the block has no selects, we can pass in any selectors and it should succeed
    my $vars = $obj->merge_blocks({gubber => 33});
    is_deeply($vars, {foo => 1});

    $vars = $obj->merge_blocks({gubber => 34});
    is_deeply($vars, {});

    $vars = $obj->merge_blocks({});
    is_deeply($vars, {});
    return;
}

sub get : Test(1)
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
    Idval::FileString::idv_add_file('/testdir/gt1.txt', "{\ngubber = 3\nhubber=4\n}\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt');
    # Since the block has no selects, we can pass in any selectors and it should succeed
    is($obj->get_single_value('flubber', {foo => 'boo'}), '');

    return;
}

sub no_matching_keys_and_a_default_should_return_default : Test(1)
{
    Idval::FileString::idv_add_file('/testdir/gt1.txt', "{\ngubber = 3\nhubber=4\n}\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt');
    is($obj->get_single_value('flubber', {}, 18), 18);

    return;
}

sub get_value_with_embedded_quotes : Test(1)
{
    Idval::FileString::idv_add_file('/testdir/gt1.txt', "{\ngubber = pachoo nachoo \"huggery muggery\" hoofah\n}\n");
    # Since the block has no selects, we can pass in any selectors and it should succeed
    my $obj = Idval::Config->new('/testdir/gt1.txt');
    is($obj->get_value('gubber', {foo => 'boo'}), 'pachoo nachoo "huggery muggery" hoofah');

    return;
}

sub get_list : Test(2)
{
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
    Idval::FileString::idv_add_file('/testdir/gt1.txt',
                                    "{\ntype == foo\ngubber = pachoo wachoo\n}\n{\ntype == boo\ngubber = bouncy\n}\n");
    my $cfg_dbg = 1;
    #my $cfg_dbg = 0;
    my $obj = Idval::Config->new('/testdir/gt1.txt', $cfg_dbg);

    is($obj->get_value('gubber', {'type' => 'foo'}), 'pachoo wachoo');

    return;

}

sub block_get_from_second_block : Test(1)
{
    Idval::FileString::idv_add_file('/testdir/gt1.txt',
                                    "{\ntype == foo\ngubber = pachoo wachoo\n}\n{\ntype == boo\ngubber = bouncy\n}\n");
    my $cfg_dbg = 0;
    my $obj = Idval::Config->new('/testdir/gt1.txt', $cfg_dbg);

    is($obj->get_value('gubber', {'type' => 'boo'}), 'bouncy');

    return;

}

sub block_get_no_matches_should_return_default : Test(1)
{
    Idval::FileString::idv_add_file('/testdir/gt1.txt',
                                    "{\ntype == foo\ngubber = pachoo wachoo\n}\n{\ntype == boo\ngubber = bouncy\n}\n");
    my $cfg_dbg = 0;
    my $obj = Idval::Config->new('/testdir/gt1.txt', $cfg_dbg);

    is($obj->get_value('gubber', {'type' => 'blargle'}, 'hubba'), 'hubba');

    return;

}

sub block_get_two_matches_should_return_last : Test(1)
{
    Idval::FileString::idv_add_file('/testdir/gt1.txt',
                                    "{\ntype == foo\ngubber = pachoo wachoo\n}\n{\ntype == foo\ngubber = bouncy\n}\n");
    my $cfg_dbg = 0;
    my $obj = Idval::Config->new('/testdir/gt1.txt', $cfg_dbg);

    is($obj->get_value('gubber', {'type' => 'foo'}, 'hubba'), 'bouncy');

    return;

}

sub block_get_with_two_selects : Test(1)
{
    Idval::FileString::idv_add_file('/testdir/gt1.txt',
                                    "{\ntype == foo\nmarley == tuff\ngubber = pachoo wachoo\n}\n{\ntype == boo\nmarley == tuff\ngubber = bouncy\n}\n");
    my $cfg_dbg = 0;
    my $obj = Idval::Config->new('/testdir/gt1.txt', $cfg_dbg);

    is($obj->get_value('gubber', {'type' => 'foo', 'marley' => 'tuff'}), 'pachoo wachoo');

    return;

}

sub block_two_blocks_select_1 : Test(1)
{
    Idval::FileString::idv_add_file('/testdir/gt1.txt',
                                    "{\ntype == foo\ngubber = pachoo wachoo\n}\n{\ntype == boo\ngubber = bouncy\n}\n");
    my $cfg_dbg = 0;
    my $obj = Idval::Config->new('/testdir/gt1.txt', $cfg_dbg);

    is($obj->get_value('gubber', {'type' => 'foo'}), 'pachoo wachoo');

    return;
}

sub barf_test_block_two_blocks_select_1a
{
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
    Idval::FileString::idv_add_file('/testdir/gt1.txt',
                                    "{\ntype == foo\ngubber = pachoo wachoo\n}\n{\ntype == boo\ngubber = bouncy\n}\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt');

    is($obj->get_value('gubber', {'type' => ['awfu', 'big', 'foo']},
                       'scooby doo'), 'pachoo wachoo');

    return;
}

sub multiple_select_key_when_no_keys_should_match : Test(1)
{
    Idval::FileString::idv_add_file('/testdir/gt1.txt',
                                    "{\ntype == foo\ngubber = pachoo wachoo\n}\n{\ntype == boo\ngubber = bouncy\n}\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt');

    is($obj->get_value('gubber', {'type' => ['awfu', 'big', 'mess']},
                       'scooby doo'), 'scooby doo');

    return;
}


sub merge_one_block : Test(1)
{
    my $cfg_file =<<EOF;
    {
        # Collect settings of use only to overall Idval configuration
        config_group == idval_settings

            provider_dir = %DATA%/Plugins
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
        'provider_dir' => "$datadir/Plugins",
        'data_store' => "$datadir/data_store.bin",
        'visible_separator' => '%%'
    };
    Idval::FileString::idv_add_file('/testdir/gt1.txt', $cfg_file);
    my $obj = Idval::Config->new('/testdir/gt1.txt');

    my $vars = $obj->merge_blocks({'config_group' => 'idval_settings'});

    # Should be just 'provider_dir through 'visible_separator'
    #print "result of merge blocks with \{'config_group' => 'idval_settings'\}: ", Dumper($vars);
    is_deeply($vars, $result);
}

sub get_one_value : Test(1)
{
    Idval::FileString::idv_add_file('/testdir/gt1.txt',
                                    "{\ntype == foo\ngubber = pachoo wachoo\n}\n{\ntype == boo\ngubber = bouncy\n}\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt');

    my $val = $obj->get_value('gubber', {'type' => 'boo'});

    is($val, 'bouncy');
    #print "val is: \"$val\"\n"; # should be 'bouncy'
}

sub get_value_using_two_selectors : Test(1)
{
    Idval::FileString::idv_add_file('/testdir/gt1.txt',
                                    "{\ntype == foo\nmarley == tuff\ngubber = pachoo wachoo\n}\n{\ntype == boo\nmarley == tuff\ngubber = bouncy\n}\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt');
    my $val = $obj->get_value('gubber', {'type' => 'foo', 'marley' => 'tuff'});
    #print "Result for \{'type' => 'foo', 'marley' => 'tuff'\}: ", Dumper($val); # Should be 'pachoo wachoo'
    is($val, 'pachoo wachoo');
}

sub get_value_using_selector_list : Test(1)
{
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
    my $cfg_file =<<EOF;
    {
    # Collect settings of use only to overall Idval configuration
    config_group == idval_settings

    provider_dir = %DATA%/Plugins
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
        'convert' => 'MIDI',
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

    # Should be just 'T' through 'abc-copyright', plus GUBBER and convert
    #print "result of merge blocks with \{'config_group' => 'tag_mappings', 'type' => 'ABC'\}: ",
    #Dumper($vars);

    is_deeply($vars, $result);
    
}

# Can we back-add inherited values?
# Nope! This masking behavior allows overrides
sub no_back_adding_of_inherited_values : Test(1)
{
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
          'A' => 'TEXT',
          'convert' => 'OGG',
          'fuffer' => 'nutter',
          'abc-copyright' => 'TCOP',
          'T' => 'TITLE',
          'X' => 'TRACK',
          'K' => 'TKEY',
          'Z' => 'TENC',
          'C' => 'TCOM',
          'D' => 'TALB'
        };
    Idval::FileString::idv_add_file('/testdir/gt1.txt', $cfg_file);
    my $obj = Idval::Config->new('/testdir/gt1.txt');

    #print "new config: ", Dumper($obj);
    my $vars = $obj->merge_blocks({'class' => 'MUSIC',
                                   'type' => 'ABC'
                                  });

    # Should be just 'T' through 'abc-copyright', plus GUBBER, fuffer, and 'convert = OGG' (not MIDI)
    #print "result of merge blocks with \{'class' => 'MUSIC', 'type' => 'ABC'\}: ", Dumper($vars);

    is_deeply($vars, $result);
}

# Can we back-add other values?
# Yep!
sub no_back_adding_of_other_values : Test(1)
{

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
          'A' => 'TEXT',
          'convert' => 'MIDI',
          'fuffer' => 'nutter',
          'abc-copyright' => 'TCOP',
          'T' => 'TITLE',
          'X' => 'TRACK',
          'K' => 'TKEY',
          'Z' => 'TENC',
          'C' => 'TCOM',
          'D' => 'TALB'
        };
    Idval::FileString::idv_add_file('/testdir/gt1.txt', $cfg_file);
    my $obj = Idval::Config->new('/testdir/gt1.txt');

    #print "new config: ", Dumper($obj);
    my $vars = $obj->merge_blocks({'class' => 'MUSIC',
                                   'type' => 'ABC'
                                  });

    # Should be just 'T' through 'abc-copyright', plus GUBBER, fuffer, and 'convert = MIDI'
    #print "result of merge blocks with \{'class' => 'MUSIC', 'type' => 'ABC'\}: ", Dumper($vars);

    is_deeply($vars, $result);
}

# Config can handle strings containing config data as well as file names
sub get_immediate : Test(1)
{
    my $obj = Idval::Config->new("{\ngubber = 3\nhubber=4\n}\n");
    is($obj->get_single_value('gubber', {foo => 'boo'}), 3);

    return;
}

sub previously_defined_variable_can_be_used_as_selector : Test(2)
{

my $cfg_file =<<EOF;
   {
    convert      = MP3
    {
        type        == ABC
        convert      = MIDI
    }
    }

    {
        config_group == tag_mappings

        argle = bargle

        {
           convert == MIDI

           argle = gargle
        }
    }
EOF

    Idval::FileString::idv_add_file('/testdir/gt1.txt', $cfg_file);
    my $obj = Idval::Config->new('/testdir/gt1.txt');

    my $val = $obj->get_value('argle', {'config_group' => 'tag_mappings'});
    is($val, 'bargle');

    # When 'type' is 'ABC', then 'convert' is set to 'MIDI', and so the 'convert == MIDI' block is selected.
    $val = $obj->get_value('argle', {'config_group' => 'tag_mappings', 'type' => 'ABC'});
    is($val, 'gargle');
}


use Carp qw(cluck);
sub pass_operator_1 : Test(1)
{

my $cfg_file =<<EOF;
   myval = 2
   {
       AAA passes TestSub

       myval = 3
   }

   {
       BBB passes TestSub

       myval = 4
   }
EOF
    no strict 'refs';
    *{'Idval::ValidateFuncs::TestSub'} = sub {
        my $selectors = shift;
        my $tagname = shift;
        #print STDERR "Hello from TestSub: tagname is $tagname\n";    
        return $tagname eq 'AAA';
    };

    Idval::FileString::idv_add_file('/testdir/gt1.txt', $cfg_file);
    #$Idval::Config::USE_LOGGER = 0;
    my $obj = Idval::Config->new('/testdir/gt1.txt');

    #print "new config: ", Dumper($obj);
    #$Idval::Config::DEBUG = 1;
    #$obj->{DEBUG} = 1;
    my $val = $obj->get_value('myval', {'AAA' => 'aaa aaa'});
    is($val, 3);
    #$Idval::Config::DEBUG = 0;
    #$Idval::Config::USE_LOGGER = 1;
}

sub regexp_selectors_1 : Test(4)
{
my $cfg_file =<<EOF;
blah_blah = 1
{
   f.* == 2

   blah_blah = 3
}
EOF

    my $obj = Idval::Config->new($cfg_file);

    is($obj->get_single_value('blah_blah', {foo => 1}), 1);
    is($obj->get_single_value('blah_blah', {foo => 2}), 3);
    is($obj->get_single_value('blah_blah', {farf => 1}), 1);
    is($obj->get_single_value('blah_blah', {farf => 2}), 3);
}

sub regexp_selectors_2 : Test(1)
{
my $cfg_file =<<EOF;
blah_blah = 1
{
   .* == 2

   blah_blah = 3
}
EOF

    my $obj = Idval::Config->new($cfg_file);

    is($obj->get_single_value('blah_blah', {foo => 1, boo => 2, goo => 2}), 3);
#is($obj->get_single_value('blah_blah', {foo => 2}), 3);
#    is($obj->get_single_value('blah_blah', {farf => 1}), 1);
#    is($obj->get_single_value('blah_blah', {farf => 2}), 3);
}

sub get_list_always_returns_an_array : Test(1)
{
my $cfg_file =<<EOF;
blah_blah = 1
{
   foo == 2

   blah_blah = 3
}
EOF

    my $obj = Idval::Config->new($cfg_file);
    is_deeply($obj->get_list_value('blah_blah', {foo => 1}), [1]);
}

sub plus_equals_creates_an_array : Test(1)
{
my $cfg_file =<<EOF;
blah_blah = 1
{
   foo == 2

   blah_blah = 3
   blah_blah += 4
}
EOF

    my $obj = Idval::Config->new($cfg_file);
    is_deeply($obj->get_list_value('blah_blah', {foo => 2}), [3, 4]);
}

sub plus_equals_creates_an_array1 : Test(1)
{
my $cfg_file =<<EOF;
{
    # Collect settings of use only to overall Idval configuration
    config_group == idval_settings

    provider_dir = Providers/Taggers
    provider_dir += Providers/Converters
    command_dir = %DATA%/Commands
    command_extension = pm
}
EOF

    my $obj = Idval::Config->new($cfg_file);
    is_deeply($obj->get_list_value('provider_dir', {'config_group' => 'idval_settings'}), [qw{Providers/Taggers Providers/Converters}]);
}

sub just_an_assignment_works : Test(1)
{
my $cfg_file =<<EOF;
blah_blah = 1
EOF

    my $obj = Idval::Config->new($cfg_file);

    is($obj->get_single_value('blah_blah'), 1);
}

our $local_foo_val;
sub Idval::Config::Methods::get_foo
{
    return [$local_foo_val];
}

sub calculated_vars_1 : Test(2)
{
my $cfg_file =<<EOF;

blah_blah = 2
{
   use_foo == 1
   __foo == 3

   blah_blah = 3
}
EOF

    $Idval::Config::Methods::method_descriptions{__foo} = "desc for get_foo";
    my $obj = Idval::Config->new($cfg_file);

    $local_foo_val = 1;
    is($obj->get_single_value('blah_blah', {use_foo => 1}), 2);

    $local_foo_val = 3;
    is($obj->get_single_value('blah_blah', {use_foo => 1}), 3);
}

1;

__END__


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
