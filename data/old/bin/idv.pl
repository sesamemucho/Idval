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
use lib ("$FindBin::Bin/../lib");

use Idval::Constants;
use Idval::ServiceLocator;
use Idval::Ui;
use Idval::Config;
use Idval::Providers;
use Idval::NewFH;
use Idval::FileIO;
use Idval::Common;
use Idval::Logger;

our (
    @standard_options,
    %options,
    $opts,

    $VERSION,

    $sysconfig_file,
    $userconfig_file,

    $config,
    $providers,
    $datastore,
    $cmd,
    $data_dir,
    $status,
    $log,

    $pod_input,
    );


$pod_input =<<EOD;

=head1 NAME

idv - IDValidator

=head1 SYNOPSIS

idv [options] command [command-options] [command-args]

=head1 OPTIONS


=head1 DESCRIPTION

B<This program> will read the given input file(s) and do something
useful with the contents thereof.

=cut

EOD

$| = 1;

$VERSION = 0.50;

@standard_options =
    (
     'help',
     'man',
     'version',
     'topdir=s',
     'input=s',
     'output=s',
     'store!',
     'sysconfig=s',
     'userconfig=s',
     'no-run',
     'xml!',                 # use XML for output

     # For error logging
     'verbose+',
     'quiet+',
     'debug=i',
     'development',
     'log_out=i',
    );

# Set defaults
$options{'help'} = '';
$options{'man'} = '';
$options{'version'} = '';
$options{'input'} = '';
$options{'output'} = '';
$options{'store'} = 1;
$options{'sysconfig'} = '';
$options{'userconfig'} = '';
$options{'no-run'} = 0;
$options{'xml'} = 0;
$options{'verbose'} = 1;
$options{'quiet'} = 0;
$options{'debug'} = undef;
$options{'development'} = 0;
$options{'log_out'} = undef;

$opts = Getopt::Long::Parser->new();
$opts->configure("require_order");
#print "Standard options are: ", join("\n", @standard_options), "\n";
my $retval = $opts->getoptions(\%options, @standard_options);

# We now know enough to fire up the error logger
my @logger_args = Idval::Common::mkarglist(
    'level' => $options{'verbose'} - $options{'quiet'},
    defined($options{'debug'}) ? ('debug' => $options{'debug'}) : '',
    $options{'development'} ? ('show_trace' => 1, 'show_time' => 1) : '',
    defined($options{'log_out'}) ? ('log_out' => $options{'log_out'}) : '',
    'xml' => $options{'xml'},
    );

Idval::Logger::_initialize_logger(@logger_args);
$log = Idval::Common::get_logger();

#$log->str();

#pod2usage(-verbose => 0)  if ($getopts{'help'});
#pod2usage(-verbose => 2)  if ($getopts{'man'});
#print_version()           if ($getopts{'version'});

my $real_lib_top = Idval::Common::get_top_dir('lib');
Idval::Common::set_top_dir(File::Spec->rel2abs($options{'topdir'})) if exists($options{'topdir'});
$data_dir = Idval::Common::get_top_dir('data');
unshift(@INC, $real_lib_top);
unshift(@INC, Idval::Common::get_top_dir());

# Tell the system to use the regular filesystem services (i.e., not the unit-testing version)
Idval::ServiceLocator::provide('io_type', 'FileSystem');

$log->info($DBG_STARTUP, "option list:", Dumper(\%options));
$log->info($DBG_STARTUP, "Looking for: <$data_dir/idval.cfg>\n");

$sysconfig_file  = $options{'sysconfig'} || "$data_dir/idval.cfg";
$userconfig_file = $options{'userconfig'} || Idval::Ui::get_userconfig_file($data_dir);
$log->info($DBG_STARTUP, "sysconfig is: \"$sysconfig_file\", userconfig is \"$userconfig_file\"\n");

$config = Idval::Config->new($sysconfig_file);
$config->add_file($userconfig_file) if $userconfig_file;

$providers = Idval::Providers->new($config);
my $typemap = Idval::TypeMap->new($providers);
#print "TypeMap:", Dumper($typemap);
Idval::Common::register_common_object('typemap', $typemap);

# Here we enter the command loop. If there are any arguments left in @ARGV,
# this is taken as a command (followed by an implicit 'exit' command).

package Idval;
$datastore = Idval::Collection->new();
my $input_datafile = $main::options{'input'};
if (@ARGV)
{
    my $cmd = shift @main::ARGV;
    if ($cmd ne 'gettags')
    {
        $datastore = main::process_command('read_data', $datastore, $main::providers, $input_datafile);
    }
    if (main::is_command_defined($cmd))
    {
        $datastore = main::process_command($cmd, $datastore, $main::providers, @main::ARGV);
        if ($datastore)
        {
            if ($options{'store'})
            {
                $datastore = main::process_command('store', $datastore, $main::providers, '');
            }
            if ($options{'output'})
            {
                $datastore = main::process_command('store', $datastore, $main::providers, $options{'output'});
            }
        }
    }
    elsif (Idval::FileIO::idv_test_exists($cmd))
    {
        print "Command file, eh?\n";
    }
    else
    {
        print("Huh?\n");
    }
}
else
{
    my $term = new Term::ReadLine 'IDValidator';
    my $prompt = "idv: ";
    my $OUT = $term->OUT || \*STDOUT;
    my $line;
    my @line_args;
    my $temp_ds;

    while (defined ($line = $term->readline($prompt)))
    {
        chomp $line;

        last if $line =~ /^\s*(quit|exit|bye)\s*$/i;

        @line_args = @{Idval::Common::split_line($line)};

        my $cmd = shift @line_args;
        if (main::is_command_defined($cmd))
        {
            $temp_ds = main::process_command($cmd, $datastore, $main::providers, @line_args);
            $term->addhistory($line) if $line =~ /\S/;
            $datastore = $temp_ds if $temp_ds;
        }
        # Is this a command file?
        elsif (Idval::FileIO::idv_test_exists($line_args[0]))
        {
            print "Command file, eh?\n";
        }
        else
        {
            print("Huh?\n");
        }
    }
}

package main;

exit;

sub process_command
{
    my $command_name = shift;

    my $subr = "Idval::$command_name";
    #print "Calling: $subr ", join(" ", @_), "\n";
    no strict 'refs';
    my $datastore = &$subr(@_);
    use strict;

    return $datastore;
}

sub is_command_defined
{
    my $command_name = shift;

    my $sub = "Idval::$command_name";

    no strict 'refs';
    my $has = defined(*$sub);
    use strict;

    return $has;
}

