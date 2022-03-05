#!/usr/bin/perl

use strict;
use warnings;
#$Devel::Trace::TRACE = 0;   # Disable
use Getopt::Long;
use Data::Dumper;
use FindBin;
use lib ("$FindBin::Bin/../lib");

use Idval::Config;

my $cfgfile = shift @ARGV;

die "Need a config file name\n" unless $cfgfile;

# Tell the system to use the regular filesystem services (i.e., not the unit-testing version)
Idval::ServiceLocator::provide('io_type', 'FileSystem');

my $cfg = Idval::Config->new($cfgfile);

print "Config subroutine is:\n\n";

print $cfg->{SUBR_TEXT};
