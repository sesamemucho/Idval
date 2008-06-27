#!/usr/bin/perl

use strict;
use warnings;
#$Devel::Trace::TRACE = 0;   # Disable
use Getopt::Long;
use Data::Dumper;
use FindBin;
use lib ("$FindBin::Bin/../lib");

use Idval::Config;
use Idval::FileIO;
use Idval::ServiceLocator;

Idval::ServiceLocator::provide('io_type', 'FileString');
my $tree1 = {'testdir' => {}};
Idval::FileString::idv_set_tree($tree1);

my $scenario = 4;

if ($scenario == 1)
{
my $cfg_file =<<EOF;
{
    # Collect settings of use only to overall Idval configuration
    config_group == idval_settings

    plugin_dir = %LIB%/Plugins
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
Idval::FileString::idv_add_file('/testdir/gt1.txt', $cfg_file);
my $obj = Idval::Config->new('/testdir/gt1.txt', 0, 1);


my $vars = $obj->merge_blocks({'config_group' => 'idval_settings'});

print "result of merge blocks with \{'config_group' => 'idval_settings'\}: ", Dumper($vars);
}
if ($scenario == 2)
{
    Idval::FileString::idv_add_file('/testdir/gt1.txt',
                                    "{\ntype == foo\ngubber = pachoo wachoo\n}\n{\ntype == boo\ngubber = bouncy}\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt', 1, 1);

    my $val = $obj->get_value('gubber', {'type' => 'boo'});

    print "val is: \"$val\"\n";
}

if ($scenario == 3)
{
    Idval::FileString::idv_add_file('/testdir/gt1.txt',
                                    "{\ntype == foo\nmarley == tuff\ngubber = pachoo wachoo\n}\n{\ntype == boo\nmarley == tuff\ngubber = bouncy}\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt', 1, 1);
    my $val = $obj->get_value('gubber', {'type' => 'foo', 'marley' => 'tuff'});
    print "Result for \{'type' => 'foo', 'marley' => 'tuff'\}: ", Dumper($val);
}

if ($scenario == 4)
{
    Idval::FileString::idv_add_file('/testdir/gt1.txt',
                                    "{\ntype == foo\ngubber = pachoo wachoo}\n{\ntype == boo\ngubber = bouncy}\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt', 1, 1);

    my $val = $obj->get_value('gubber',
                              {'type' => ['awfu', 'big', 'foo']},
                              'scooby doo');

    print "Result for : {'type' => ['awfu', 'big', 'foo']}", Dumper($val);
    
}

