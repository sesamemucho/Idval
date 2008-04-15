#!/usr/bin/perl -w

use strict;

use Getopt::Long;
use Test::Unit::Debug qw(debug_pkgs);
use Test::Unit::TestRunner;
use File::Glob ':glob';
use File::Path;
use FindBin;
use lib ("$FindBin::Bin/../lib", "$FindBin::Bin/../tsts/accept");
#use lib "$FindBin::Bin/../lib";

use Idval::Logger;
use Idval::Common;

our (
    @standard_options,
    %options,
    );

@standard_options =
    (
     'verbose+',
     'quiet+',
     'debug=i',
     'development',
     'log_out=i',
    );

my $opts = Getopt::Long::Parser->new();
my $retval = $opts->getoptions(\%options, @standard_options);

$options{'verbose'} = 0;
$options{'quiet'} = 0;
$options{'development'} = 0;
$options{'log_out'} = undef;

# We now know enough to fire up the error logger
my @logger_args = Idval::Common::mkarglist(
    'level' => $options{'verbose'} - $options{'quiet'},
    defined($options{'debug'}) ? ('debug' => $options{'debug'}) : '',
    $options{'development'} ? ('show_trace' => 1, 'show_time' => 1) : '',
    defined($options{'log_out'}) ? ('log_out' => $options{'log_out'}) : '',
    );

Idval::Logger::_initialize_logger(@logger_args);
my $log = Idval::Logger::get_logger();
#print STDERR $log->str(), "\n";

my @pkgs = bsd_glob("$FindBin::Bin/../tsts/accept/*Test.pm");

# Uncomment and edit to debug individual packages.
#debug_pkgs(qw/Test::Unit::TestCase/);

foreach my $pkg (@pkgs)
{
    my $testrunner = Test::Unit::TestRunner->new();
    $testrunner->start($pkg);
}

rmtree(['tsts/accept_data/ValidateTest/t']);
