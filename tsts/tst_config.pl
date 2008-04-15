#
# Tests Idval::Config
#
use strict;
use lib 'lib/perl';

use Test::More qw(no_plan);
use Data::Dumper;

use Idval::Config;

my $cfg = new Idval::Config();

is(ref $cfg, "Idval::Config", "tst_config test 1");

