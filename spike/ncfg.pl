#!/usr/bin/perl -w
use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use Data::Dumper;
use Carp;
use FindBin;
use lib ("$FindBin::Bin/../lib", "$FindBin::Bin/../tsts", "$FindBin::Bin/../lib/perl/JSON-1.15/lib");

use JSON;

my $json = new JSON;

# my $obj = {
#     id   => ["foo", "bar", { aa => 'bb'}],
#     hoge => 'boge'
#  };

# my $js  = objToJson($obj);

# print "js is: \"$js\"\n";

# # pretty-printing
# $js = $json->objToJson($obj, {pretty => 1, indent => 2});

# print "pretty js is: \"$js\"\n";

# Can we have anonymous objects? (nope; need name:value pairs)
my $j1 =<<EOF;
{
"guff": "huff",
"arr1": [{
    "foo1": 1,
    "boo1": 2
}],
"luff": "sail",
"h2" : {
    "foo2": 10,
    "boo2": 20
}
}
EOF

    my $o1 = jsonToObj($j1);

#print "o1:", Dumper($o1);

# how about same-names in different objects?
my $j2 =<<EOF;
{
"guff": "huff",
"arr1": [{
    "foo1": 1,
    "boo1": 2
}],
"luff": "sail",
"h2" : {
    "foo1": 10,
    "boo1": 20
}
}
EOF

    my $o2 = jsonToObj($j2);

#print "o2:", Dumper($o2);

# how about same-names in same object? Nope - later overwrites earlier
my $j2a =<<EOF;
{
"guff": "huff",
"arr1": [{
    "foo1": 1,
    "boo1": 2
}],
"luff": "sail",
"arr1" : {
    "foo2": 10,
    "boo2": 20
}
}
EOF

    my $o2a = jsonToObj($j2a);

print "o2a:", Dumper($o2a);

my $j3 =<<EOF;
{
    "sets": {
            "class": "MUSIC",
            "convert": "MP3"
    },

     "children": [
         {
             "selects":
             {
                 "config_group":
                     {
                          "cmp":  "equals",
                          "value": "idval_settings"
                     }
             },

             "sets":
             {
                 "provider_dir": "%LIB%/Plugins",
                 "command_dir": "%DATA%/commands",
                 "command_extension": "pm",
                 "data_store": "%DATA%/data_store.bin"
             },

             "appends":
             {
             }
         },

         {
             "selects":
             {
                 "command_name":
                     {
                         "cmp":  "equals",
                         "value": "lame"
                     }
             },

             "sets":
             {
                 "command_path": "~/local/bin/lame.exe"
             }
         },

         {
             "selects":
             {
                 "command_name":
                     {
                         "cmp":  "equals",
                         "value": "tag"
                     }
             },

             "sets":
             {
                 "command_path": "~/local/bin/Tag.exe"
             }
         },

         {
             "selects":
             {
                 "class":
                     {
                       "cmp":  "equals",
                       "value": "MUSIC"
                     }
             },

             "sets":
             {
                 "convert": "MP3"
             },

             "children": [
                 {
                     "selects":
                     {
                         "type":
                             {
                                 "cmp":  "equals",
                                 "value": "ABC"
                             }
                     },
                    
                     "sets":
                     {
                         "convert": "MIDI"
                     }
                 }
             ]
         }
     ]
}
EOF

my $o3 = jsonToObj($j3);

print "o3:", Dumper($o3);
