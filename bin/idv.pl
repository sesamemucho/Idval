#!/usr/bin/perl -w
use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use Data::Dumper;
use File::Spec;
use Carp;
use Cwd;
use Term::ReadLine;
use FindBin;
use lib ("$FindBin::Bin/../lib", "$FindBin::Bin/../tsts");
#use lib (getcwd() . "/lib", getcwd() . "/tsts");

use Idval;

$| = 1;

my $idval = Idval->new(\@ARGV);

$idval->cmd_loop();
