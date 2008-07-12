package Idval;

# Copyright 2008 Bob Forgey <rforgey@grumpydogconsulting.com>

# This file is part of Idval.

# Idval is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# Idval is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with Idval.  If not, see <http://www.gnu.org/licenses/>.
$Devel::Trace::TRACE = 0;
use strict;
use warnings;

use Data::Dumper;
use File::Spec;
use Carp;
use Cwd;
use Term::ReadLine;

use Idval::Constants;
use Idval::ServiceLocator;
use Idval::Ui;
use Idval::Config;
use Idval::Providers;
use Idval::NewFH;
use Idval::FileIO;
use Idval::Common;
use Idval::Logger;
use Idval::Help;

my @standard_options;
my %options;
my $VERSION;
our $AUTOLOAD;  ## no critic (ProhibitPackageVars)
my $log;

local $| = 1;

$VERSION = 0.50;

@standard_options =
    (
     'help',
     'man',
     'Version',
     'topdir=s',
     'input=s',
     'output=s',
     'print_to=s',
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
$options{'log_out'} = '';
$options{'print_to'} = '';

sub new
{
    my $class = shift;
    my $self = {};
    bless($self, ref($class) || $class);
    $self->_init(@_);
    return $self;
}

sub _init
{
    my $self = shift;
    my $argref = shift;

    my $lfh;
    my @realargv = @ARGV;
    my @other_args = ();

    if (!defined($argref))
    {
        $argref = \@realargv;
    }

    if (ref $argref eq 'ARRAY')
    {
        # We need to do our own argument parsing
        local @ARGV = @{$argref};

        my $opts = Getopt::Long::Parser->new();
        $opts->configure("require_order", "no_ignore_case");
        #print "Standard options are: ", join("\n", @standard_options), "\n";
        my $retval = $opts->getoptions(\%options, @standard_options);
        @other_args = (@ARGV);
    }
    else
    {
        # We got passed in the options
        %options = (%options, %{$argref});
    }

    $self->{OPTIONS} = \%options;

    # We now know enough to fire up the error logger
    my @logger_args = Idval::Common::mkarglist(
        'level' => $options{'verbose'} - $options{'quiet'},
        defined($options{'debug'}) ? ('debugmask' => $options{'debug'}) : '',
        $options{'development'} ? ('show_trace' => 1, 'show_time' => 1) : '',
        'log_out' => $options{'log_out'},
        'print_to' => $options{'print_to'},
        'xml' => $options{'xml'},
        );
#         defined($options{'log_out'}) ? ('log_out' => $options{'log_out'}) : '',
#         defined($options{'print_to'}) ? ('print_to' => $options{'print_to'}) : '',

    Idval::Logger::initialize_logger(@logger_args);
    $log = Idval::Common::get_logger();

    # Set up a common location for help info
    my $help_info = Idval::Help->new();
    Idval::Common::register_common_object('help_file', $help_info);

    $self->set_pod_input();

    #$log->str();

    #pod2usage(-verbose => 0)  if ($getopts{'help'});
    #pod2usage(-verbose => 2)  if ($getopts{'man'});
    #print_version()           if ($getopts{'version'});

    my $real_lib_top = Idval::Common::get_top_dir('lib');
    Idval::Common::set_top_dir(File::Spec->rel2abs($options{'topdir'})) if exists($options{'topdir'});
    my $data_dir = Idval::Common::get_top_dir('data');
    unshift(@INC, $real_lib_top);
    unshift(@INC, Idval::Common::get_top_dir());

    # Tell the system to use the regular filesystem services (i.e., not the unit-testing version)
    Idval::ServiceLocator::provide('io_type', 'FileSystem');

    $log->verbose($DBG_STARTUP, "option list:", Dumper(\%options));
    $log->verbose($DBG_STARTUP, "Looking for: <$data_dir/idval.cfg>\n");

    my $sysconfig_file  = $options{'sysconfig'} || "$data_dir/idval.cfg";
    my $userconfig_file = $options{'userconfig'} || Idval::Ui::get_userconfig_file($data_dir);
    $log->verbose($DBG_STARTUP, "sysconfig is: \"$sysconfig_file\", userconfig is \"$userconfig_file\"\n");

    my $config = Idval::Config->new($sysconfig_file);
    $config->add_file($userconfig_file) if $userconfig_file;

# XXX This really should be done during installation
#     # Is this the first time through?
#     if (not $config->value_exists('use_cache_file', {config_group => 'idval_settings'}))
#     {
#         require Idval::FirstTime;
#         my $cfgfile = Idval::FirstTime::init($config);
#         $config->add_file($cfgfile);
#     }

    $self->{CONFIG} = $config;
    Idval::Common::register_common_object('config', $self->config());
    $self->{PROVIDERS} = Idval::Providers->new($config);
    Idval::Common::register_common_object('providers', $self->providers());
    $self->{TYPEMAP} = Idval::TypeMap->new($self->providers());
    Idval::Common::register_common_object('typemap', $self->typemap());

    $self->{DATASTORE} = Idval::Collection->new({contents => '', source => 'blank'});

    $self->{REMAINING_ARGS} = [@other_args];
    $log->chatty($DBG_PROVIDERS, "Remaining args: <", join(", ", @{$self->{REMAINING_ARGS}}), ">\n");

    return;
}

# Here we enter the command loop. If there are any arguments left in @ARGV,
# this is taken as a command (followed by an implicit 'exit' command).
sub cmd_loop
{
    my $self = shift;

    my @args = @{$self->{REMAINING_ARGS}};
    my $input_datafile = $self->{OPTIONS}->{'input'};

    if (@args)
    {
        my $cmd = shift @args;
        my $rtn = 'Idval::Scripts::' . $cmd;
        no strict 'refs';
        if ($cmd ne 'gettags')
        {
            my $read_rtn = 'Idval::Scripts::read';
            $self->{DATASTORE} = &$read_rtn($self->datastore(),
                                            $self->providers(),
                                            $input_datafile);
        }

        $self->{DATASTORE} = &$rtn($self->datastore(),
                                   $self->providers(),
                                   @args);

        if ($self->datastore())
        {
            my $store_rtn = 'Idval::Scripts::store';
            no strict 'refs';
            if ($options{'store'})
            {
                $self->{DATASTORE} = &$store_rtn($self->datastore(),
                                                 $self->providers(),
                                                 '');
            }
            if ($options{'output'})
            {
                $self->{DATASTORE} = &$store_rtn($self->datastore(),
                                                 $self->providers(),
                                                 $options{'output'});
            }

        }

        use strict;
    }
    else
    {
        my $term = new Term::ReadLine 'IDValidator';
        my $prompt = "idv: ";
        my $OUT = $term->OUT || \*STDOUT;
        my $line;
        my @line_args;
        my $temp_ds;
        my $error_occurred;

        while (defined ($line = $term->readline($prompt)))
        {
            chomp $line;

            last if $line =~ /^\s*(q|quit|exit|bye)\s*$/i;
            next if $line =~ /^\s*$/;

            @line_args = @{Idval::Common::split_line($line)};

            my $cmd_name = shift @line_args;
            $log->chatty($DBG_PROVIDERS, "command name: \"$cmd_name\", line args: ", join(" ", @line_args), "\n");
            my $rtn = 'Idval::Scripts::' . $cmd_name;
            no strict 'refs';
            eval { $temp_ds = &$rtn($self->datastore(), $self->providers(), @line_args); };
            use strict;
            $error_occurred = 0;
            if ($@)
            {
                my $status = $!;
                my $reason = $@;
                if ($reason =~ /No script file found for command \"([^""]+)\"/)
                {
                    my $bogus = $1;
                    print "Got unrecognized command \"$bogus\", with args ", join(",", @line_args), "\n";
                    print "$@\n";
                    $error_occurred = 1;
                }
                else
                {
                    print STDERR "Yipes\n";
                    croak "Error in \"$cmd_name\": \"$status\", \"$reason\"\n";
                }
            }
            next if $error_occurred;

            $term->addhistory($line) if $line =~ /\S/;
            $self->{DATASTORE} = $temp_ds if $temp_ds;
        }
    }

    return;
}

# Note:
# main::(-e:1):   0
#   DB<1> $a = sub{my $x=shift; print "Hello \"$x\"\n";}

#   DB<2> &$a(44)
# Hello "44"

#   DB<3> *barf{CODE} = $a
# Can't modify glob elem in scalar assignment at (eval 7)[/usr/lib/perl5/5.8/perl5db.pl:628] line 2, at EOF

#   DB<4> *barf = *a

#   DB<5> barf(33)
# Undefined subroutine &main::a called at (eval 9)[/usr/lib/perl5/5.8/perl5db.pl:628] line 2.

#   DB<6> *barf = $a

#   DB<7> barf(33)
# Hello "33"


sub process_command
{
    my $self = shift;
    my $command_name = shift;

    my $subr = "Idval::Scripts::$command_name";
    #print "Calling: $subr ", join(" ", @_), "\n";
    no strict 'refs';
    my $datastore = &$subr(@_);
    use strict;

    return $datastore;
}

sub is_command_defined
{
    my $self = shift;
    my $command_name = shift;

    my $sub = "Idval::Scripts::$command_name";

    no strict 'refs';
    my $has = defined(*$sub);
    use strict;

    return $has;
}

sub config
{
    my $self = shift;

    return $self->{CONFIG};
}

sub providers
{
    my $self = shift;

    return $self->{PROVIDERS};
}

sub typemap
{
    my $self = shift;

    return $self->{TYPEMAP};
}

sub datastore
{
    my $self = shift;

    return $self->{DATASTORE};
}

package Idval::Scripts;
use Carp;
use Idval::Common;
use Idval::Constants;

our $AUTOLOAD;

# We should only get here if the command has not (previously) been defined.
sub AUTOLOAD  ## no critic (RequireFinalReturn)
{
    my $rtn = $AUTOLOAD;
    my $name;
    ($name = $rtn) =~ s/^.*::([^:]+)$/$1/;

    return if $name =~ m/^[[:upper:]]+$/;

    #print STDERR "Checking \"$name\"\n";
    $log->chatty($DBG_PROVIDERS, "In autoload, checking \"$name\"\n");
    my $providers = Idval::Common::get_common_object('providers');
    croak "ERROR: Command \"$rtn\" called too early\n" unless defined $providers;

    $log->chatty($DBG_PROVIDERS, "In autoload; rtn is \"$rtn\"\n");

    my $subr = $providers->find_command($name);

    no strict 'refs';
    *$rtn = $subr;              # For next time, so we don't go through AUTOLOAD again

    goto &$rtn;

    use strict;
}

package Idval;

sub set_pod_input
{
    my $self = shift;
    my $help_file = Idval::Common::get_common_object('help_file');

    my $pod_input =<<"EOD";

=head1 NAME

Idv.pl - Idval command interpreter

=head1 SYNOPSIS

sample [options] [file ...]

 Options:
   -help            brief help message
   -man             full documentation

=head1 OPTIONS

=over 8

=item B<-help>

Print a brief help message and exits.

=item B<-man>

Prints the manual page and exits.

=back

=head1 DESCRIPTION

B<This program> will read the given input file(s) and do something
useful with the contents thereof.

=cut

EOD
    $help_file->{'main'} = $pod_input;

    return;
}

1;
