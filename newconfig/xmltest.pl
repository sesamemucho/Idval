#!/usr/bin/perl

use strict;
use warnings;
#$Devel::Trace::TRACE = 0;   # Disable
use Getopt::Long;
use Data::Dumper;
use FindBin;
use lib ("$FindBin::Bin/../lib/perl");

use XML::Simple;
use YAML::Tiny;

#my $c = XMLin('a.xml', keyattr => {set => 'name', select => 'name'}, forcearray => [ qw(set select) ]);
#my $c = XMLin('b.xml');
#my $c = XMLin('c.xml');
my $c = XMLin('d.xml', keyattr => {select=>'name'}, forcearray => ['select']);

print Dumper($c);
print YAML::Tiny::Dump($c);
