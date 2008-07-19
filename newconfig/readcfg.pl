#!/usr/bin/perl

use strict;
use warnings;
#$Devel::Trace::TRACE = 0;   # Disable
use Getopt::Long;
use Data::Dumper;
use IO::File;
use Carp;
use FindBin;
use lib ("$FindBin::Bin/../lib", "$FindBin::Bin/../lib/perl");
use XML::Simple;
use YAML::Tiny;
use Idval::Select;

my $fname = 'a.cfg';
my $fh = IO::File->new($fname, "r") || do {print STDERR Carp::shortmess("shormess");
                                             croak "Can't open \"$fname\" for reading: $! in " . __PACKAGE__ . " line(" . __LINE__ . ")";};
my $text = do { local $/ = undef; <$fh> };
$fh->close();

my $xml = config_to_xml($text);

#print "Got: $xml\n";
my $c = XMLin($xml, keyattr => {select=>'name'}, forcearray => ['select']);

print Dumper($c);
#print YAML::Tiny::Dump($c);

#visit($c, 'top', 0, \&check_it_out);

merge_blocks($c, {config_group => 'idval_settings'});
exit;

sub visit
{
    my $noderef = shift;
    my $name = shift;
    my $level = shift;
    my $subr = shift;

    #confess "top is undefined?" unless defined $top;
    print("visiting \"$name\"\n");
    #print "ref of \"$name\": ", ref $noderef, "\n";
    #print "keys of \"$name\": ", join(', ', keys %{$noderef}), "\n";
    #print "ref of group: ", ref($noderef->{'group'}), "\n";
    #print "dump of group: ", Dumper($noderef->{'group'});
    #print "group: " , join(", ", @{$noderef->{'group'}}), "\n";
    my $retval = &$subr($noderef);

    # If retval is undef, this node is not for us
    # and therefore, none of its children are, either
    #chatty("return from subr on ", $top->myname(), " is undef\n") if not defined($retval);
    #return if not defined($retval);

    # get_children returns a list of child nodes, sorted
    # by nodename.
    # The children of this node are the items in the list keyed by 'group' (if it exists)
    # Allow the existence of a plain tag named 'group'.
    my @kids = ();
    if (exists($noderef->{'group'}) && ref($noderef->{'group'}) eq 'ARRAY')
    {
        @kids = @{$noderef->{'group'}};
    }

    print "kids of \"$name\": ", join(", ", @kids), "\n";
    my $nameid = sprintf "node%03d000", $level;
    $level++;
    foreach my $child (@kids)
    {
        visit($child, $nameid++, $level, $subr);
    }

    return;
}

sub merge_blocks
{
    my $tree = shift;
    my $selects = shift;
    my %vars;

    print("Start of _merge_blocks, selects: ", Dumper($selects));

    my $visitor = sub {
        my $noderef = shift;

        return if evaluate($noderef, $selects) == 0;

        foreach my $key (sort keys %{$noderef})
        {
            my $value = $noderef->{$key};
            next if ref $value;

            $vars{$key} = $value;
        }

        return 1;
    };

    visit($tree, 'top', 0, $visitor);

    print("Result of merge blocks - VARS: ", Dumper(\%vars));

    return \%vars;
}

sub evaluate
{
    my $noderef = shift;
    my $select_list = shift;
    my $retval = 1;

    print "in evaluate: ", Dumper($noderef);
    print "select_list: ", Dumper($select_list);
    # If the block has no selector keys itself, then all matches should succeed
    return 1 unless (exists($noderef->{'select'}) && ref($noderef->{'select'}) eq 'HASH');
#my $stor = $noderef->{'select'}->{$selector};
#print "select $selector op $stor->{'op'} against $stor->{'value'}\n";
#Got selector(s)
#select DATE op == against YEAR
#select type op == against FLAC

    my %selectors = %{$select_list};

    return 0 unless %selectors;

    foreach my $block_key (keys %{$noderef->{'select'}})
    {
        print("Checking block selector \"$block_key\"\n");
        if (!exists($select_list->{$block_key}))
        {
            # The select list has nothing to match a required selector, so this must fail
            return 0;
        }
        my $bstor = $noderef->{'select'}->{$block_key};

        my $arg_value_list = ref $selectors{$block_key} eq 'ARRAY' ? $selectors{$block_key} : [$selectors{$block_key}];
        # Now, arg_value is guaranteed to be a list reference

        my $block_op = $bstor->{'op'};
        my $block_value = $bstor->{'value'};
        my $block_cmp_func = Idval::Select::get_compare_function($block_op, 'STR');
        my $cmp_result = 0;

        # For any key, the passed_in selector may have a list of values that it can offer up to be matched.
        # A successful match for any of these values constitutes a successful match for the block selector.
        foreach my $value (@{$arg_value_list})
        {
            print("Comparing \"$value\" \"$block_op\" \"$block_value\" resulted in ",
                  &$block_cmp_func($value, $block_value) ? "True\n" : "False\n");

            $cmp_result ||= &$block_cmp_func($value, $block_value);
            last if $cmp_result;
        }

        $retval &&= $cmp_result;
        last if !$retval;
    }

    print("evaluate returning $retval\n");
    return $retval;
}

sub check_it_out
{
    my $noderef = shift;

    if(exists($noderef->{'select'}))
    {
        print "Got selector(s)\n";
        foreach my $selector (keys %{$noderef->{'select'}})
        {
            my $stor = $noderef->{'select'}->{$selector};
            print "select $selector op $stor->{'op'} against $stor->{'value'}\n";
        }
        print "\n";
    }

    foreach my $key (sort keys %{$noderef})
    {
        next if ref $noderef->{$key};

        print "Got assignment: $key = $noderef->{$key}\n";
    }

    return;
}

sub config_to_xml
{
    my $cfg_text = shift;
    my $xml = "<config>\n";
    my $cmp_regex = Idval::Select::get_cmp_regex();
    my $assign_regex = Idval::Select::get_assign_regex();

    foreach my $line (split(/\n|\r\n|\r/, $cfg_text))
    {
        #print "Looking at: <$line>\n";

        $line =~ /^\s*{\s*$/ and do {
            $xml .= "<group>\n";
            next;
        };

        $line =~ /^\s*}\s*$/ and do {
            $xml .= "</group>\n";
            next;
        };

        $line =~ /^\s*(#.*)$/ and do {
            $xml .= "<!-- $1 -->\n";
            next;
        };

        $line =~ m/^\s*$/ and do {
            next;
        };

        $line =~ m{^\s*([[:alnum:]][\w-]*)($cmp_regex)(.*)\s*$}imx and do {
            my $name = $1;
            my $op = $2;
            my $value = $3;
            $op =~ s/^\s+//;
            $op =~ s/\s+$//;
            $xml .= "<select name=\"$name\" op=\"$op\" value=\"$value\"/>\n";
            next;
        };
        
        $line =~ m{^\s*([[:alnum:]][\w-]*)($assign_regex)(.*)\s*$}imx and do {
            $xml .= "<$1>$3</$1>\n";
            next;
        };
        

        print "Unrecognized input line <$line>\n";
    }

    $xml .= "</config>\n";
    return $xml;
}






__END__





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

# Should be just 'plugin_dir through 'visible_separator'
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
