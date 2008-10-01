#!/usr/bin/perl

use strict;
use warnings;
#$Devel::Trace::TRACE = 0;   # Disable
use Getopt::Long;
use Data::Dumper;
use FindBin;
use lib ("$FindBin::Bin/../lib/perl");

use YAML::Tiny;
use XML::Simple;

my $c = YAML::Tiny->read('a.yml');

print "c: ", Dumper($c);

my $hr = $$c[1];

print "hr: ", Dumper($hr);

print "xml:\n", XMLout($hr);
__END__
my @a = (
    { haha => 'hoho',
      baba => 'bobo'}, 
    joe => 1,
    { dada => 'dodo',
      fafa => 'fofo',
      list => [
          { gaga => 'gogo',
            haha => 'hoho'
          },
          { lala => 'lolo',
            mama => 'momo'
          }
          ],
    }
    );


print YAML::Tiny::Dump(\@a);

my $b =<<EOF;
---
-
  select: config_group == idval_settings
  provider_dir: "%LIB%/Plugins"
  command_dir: "%DATA%/commands"
  command_extension: pm
  data_store: "%DATA%/data_store.bin"
  demo_validate_cfg: "%DATA%/val_demo.cfg"
  visible_separator: "%%"
-
  select: command_name == lame
  command_path: ~/local/bin/lame.exe
-
  select: command_name == tag
  command_path: ~/local/bin/Tag.exe
-
  select: command_name == timidity
  command_path: /cygdrive/c/Program Files/Timidity++ Project/Timidity++/timidity.exe
  config_file: /cygdrive/h/local/share/freepats/crude.cfg
-
  # Set up default conversions (any MUSIC file should be converted to .mp3)
  select: class == MUSIC
  convert: MP3
  list:
    -
      select: type == ABC
      convert: MIDI

-
  select: config_group == tag_mappings
  list:
    -
     select: type == ABC

     T: TITLE
     C: TCOM
     D: TALB
     A: TEXT
     K: TKEY
     Z: TENC
     X: TRACK
     abc-copyright: TCOP
   -
     select: type == OGG
     TRACKNUMBER: TRACK
     DATE: YEAR
   -
     select: type:= FLAC

     TRACKNUMBER: TRACK
     DATE: YEAR
EOF

    #my $c = YAML::Tiny::Load($b);

my $b =<<EOF;
---
farfar:
  - 1
  - 2
  - 3
  - 4
jack:
  gubber:
    - fuff
    - foo: 1
      foob: 2
    -
      boo: 2
    -
      goo: 3
  jill: 3
  jim: 4
joe: 1
EOF
