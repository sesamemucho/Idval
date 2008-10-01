#!/usr/bin/perl

use strict;
use warnings;
#$Devel::Trace::TRACE = 0;   # Disable
use Getopt::Long;
use Data::Dumper;
use FindBin;
use lib ("$FindBin::Bin/../lib");

use Idval::Select;














Idval::ServiceLocator::provide('io_type', 'FileString');
my $tree1 = {'testdir' => {}};
Idval::FileString::idv_set_tree($tree1);

my $scenario = 8;

if ($scenario == 1)
{
my $cfg_file =<<EOF;
{
    # Collect settings of use only to overall Idval configuration
    config_group == idval_settings

    provider_dir = %LIB%/Plugins
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

# Should be just 'provider_dir through 'visible_separator'
print "result of merge blocks with \{'config_group' => 'idval_settings'\}: ", Dumper($vars);
}

if ($scenario == 2)
{
    Idval::FileString::idv_add_file('/testdir/gt1.txt',
                                    "{\ntype == foo\ngubber = pachoo wachoo\n}\n{\ntype == boo\ngubber = bouncy}\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt', 1, 1);

    my $val = $obj->get_value('gubber', {'type' => 'boo'});

    print "val is: \"$val\"\n"; # should be 'bouncy'
}

if ($scenario == 3)
{
    Idval::FileString::idv_add_file('/testdir/gt1.txt',
                                    "{\ntype == foo\nmarley == tuff\ngubber = pachoo wachoo\n}\n{\ntype == boo\nmarley == tuff\ngubber = bouncy}\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt', 1, 1);
    my $val = $obj->get_value('gubber', {'type' => 'foo', 'marley' => 'tuff'});
    print "Result for \{'type' => 'foo', 'marley' => 'tuff'\}: ", Dumper($val); # Should be 'pachoo wachoo'
}

if ($scenario == 4)
{
    Idval::FileString::idv_add_file('/testdir/gt1.txt',
                                    "{\ntype == foo\ngubber = pachoo wachoo}\n{\ntype == boo\ngubber = bouncy}\n");
    my $obj = Idval::Config->new('/testdir/gt1.txt', 1, 1);

    my $val = $obj->get_value('gubber',
                              {'type' => ['awfu', 'big', 'foo']},
                              'scooby doo');

    print "Result for : {'type' => ['awfu', 'big', 'foo']}", Dumper($val); #  Should be 'pachoo wachoo'
    
}

if ($scenario == 5)
{
my $cfg_file =<<EOF;
{
    # Collect settings of use only to overall Idval configuration
    config_group == idval_settings

    provider_dir = %LIB%/Plugins
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
Idval::FileString::idv_add_file('/testdir/gt1.txt', $cfg_file);
my $obj = Idval::Config->new('/testdir/gt1.txt', 0, 1);

#print "new config: ", Dumper($obj);
my $vars = $obj->merge_blocks({'config_group' => 'tag_mappings',
                                                  'type' => 'ABC'
                                                 });

# Should be just 'T' through 'abc-copyright', plus GUBBER
print "result of merge blocks with \{'config_group' => 'tag_mappings', 'type' => 'ABC'\}: ", Dumper($vars);
}

if ($scenario == 6)
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
}

EOF
Idval::FileString::idv_add_file('/testdir/gt1.txt', $cfg_file);
my $obj = Idval::Config->new('/testdir/gt1.txt', 0, 1);

#print "new config: ", Dumper($obj);
my $vars = $obj->merge_blocks({'class' => 'MUSIC',
                               'type' => 'FLAC'
                              });

# Should be just 'T' through 'abc-copyright', plus GUBBER
print "result of merge blocks with \{'class' => 'MUSIC', 'type' => 'FLAC'\}: ", Dumper($vars);
}

# Can we back-add inherited values?
# Nope! This masking behavior allows overrides
if ($scenario == 7)
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
Idval::FileString::idv_add_file('/testdir/gt1.txt', $cfg_file);
my $obj = Idval::Config->new('/testdir/gt1.txt', 0, 1);

#print "new config: ", Dumper($obj);
my $vars = $obj->merge_blocks({'class' => 'MUSIC',
                               'type' => 'ABC'
                              });

# Should be just 'T' through 'abc-copyright', plus GUBBER
print "result of merge blocks with \{'class' => 'MUSIC', 'type' => 'ABC'\}: ", Dumper($vars);
}

# Can we back-add other values?
# Yep!
if ($scenario == 8)
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
Idval::FileString::idv_add_file('/testdir/gt1.txt', $cfg_file);
my $obj = Idval::Config->new('/testdir/gt1.txt', 0, 1);

#print "new config: ", Dumper($obj);
my $vars = $obj->merge_blocks({'class' => 'MUSIC',
                               'type' => 'ABC'
                              });

# Should be just 'T' through 'abc-copyright', plus GUBBER
print "result of merge blocks with \{'class' => 'MUSIC', 'type' => 'ABC'\}: ", Dumper($vars);
}
