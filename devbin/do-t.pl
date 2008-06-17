#!/usr/bin/perl -w

use strict;
#$Devel::Trace::TRACE = 0;   # Disable
use Getopt::Long;
use Test::Unit::Debug qw(debug_pkgs);
use Test::Unit::TestRunner;
use File::Glob ':glob';
use FindBin;
use lib ("$FindBin::Bin/../lib", "$FindBin::Bin/../tsts/unit");
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

$options{'verbose'} = 1;
$options{'quiet'} = 0;
$options{'development'} = 0;
$options{'log_out'} = undef;

my $opts = Getopt::Long::Parser->new();
my $retval = $opts->getoptions(\%options, @standard_options);

# We now know enough to fire up the error logger
my @logger_args = Idval::Common::mkarglist(
    'level' => $options{'verbose'} - $options{'quiet'},
    defined($options{'debug'}) ? ('debugmask' => $options{'debug'}) : '',
    $options{'development'} ? ('show_trace' => 1, 'show_time' => 1) : '',
    defined($options{'log_out'}) ? ('log_out' => $options{'log_out'}) : '',
    );

Idval::Logger::initialize_logger(@logger_args);
my $log = Idval::Logger::get_logger();
print STDERR $log->str(), "\n";

#my @pkgs = bsd_glob("$FindBin::Bin/../tsts/unit/CommandTest.pm");
#my @pkgs = bsd_glob("$FindBin::Bin/../tsts/unit/ConfigTest.pm");
#my @pkgs = bsd_glob("$FindBin::Bin/../tsts/unit/ConverterTest.pm");
#my @pkgs = bsd_glob("$FindBin::Bin/../tsts/unit/DataFileTest.pm");
#my @pkgs = bsd_glob("$FindBin::Bin/../tsts/unit/FileParseTest.pm");
#my @pkgs = bsd_glob("$FindBin::Bin/../tsts/unit/FileStringTest.pm");
my @pkgs = bsd_glob("$FindBin::Bin/../tsts/unit/GraphTest.pm");
#my @pkgs = bsd_glob("$FindBin::Bin/../tsts/unit/ProviderTest.pm");
#my @pkgs = bsd_glob("$FindBin::Bin/../tsts/unit/RecordTest.pm");
#my @pkgs = bsd_glob("$FindBin::Bin/../tsts/unit/TypeMapTest.pm");


#my @pkgs = bsd_glob("$FindBin::Bin/../tsts/unit/*Test.pm");

# Re-create the test data, if needed
#system("perl $FindBin::Bin/mktree.pl -q");

# Uncomment and edit to debug individual packages.
#debug_pkgs(qw/Test::Unit::TestCase/);

foreach my $pkg (@pkgs)
{
    my $testrunner = Test::Unit::TestRunner->new();
    print STDERR "Running $pkg...\n";
    $testrunner->start($pkg);
}
