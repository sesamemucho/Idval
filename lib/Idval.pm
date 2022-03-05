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
#use threads;
use strict;
use warnings;
use 5.006;

use Getopt::Long;
use Data::Dumper;
use File::Spec;
use Cwd;

use Idval::I18N;
use Idval::Logger qw(idv_print verbose chatty);
use Idval::ServiceLocator;
use Idval::Ui;
use Idval::Config;
use Idval::ProviderMgr;
use Idval::FileIO;
use Idval::Common;
use Idval::Help;

my %option_names;
my @standard_options_in;
my @standard_options;
my %options_in;
my %options;

our $VERSION;
our $AUTOLOAD;  ## no critic (ProhibitPackageVars)
my $log;
my $tempfiles = [];

local $| = 1;

$VERSION = '0.7.0';

@standard_options_in =
    (
     'help',
     'man',
     'Version',
     'output=s',
     'print_to=s',
     'sysconfig=s',
     'userconfig=s',
     'no-run',
     'xml!',                 # use XML for output

     # For error logging
     'optimize!',
     'verbose+',
     'quiet+',
     'debug=s',
     'development',
     'log_out=i',
    );

# Set defaults
$options_in{'help'} = '';
$options_in{'man'} = '';
$options_in{'version'} = '';
$options_in{'output'} = '';
$options_in{'sysconfig'} = '';
$options_in{'userconfig'} = '';
$options_in{'no-run'} = 0;
$options_in{'xml'} = 0;
$options_in{'verbose'} = 1;
$options_in{'quiet'} = 0;
$options_in{'development'} = 0;
$options_in{'log_out'} = '';
$options_in{'print_to'} = '';
$options_in{'optimize'} = 1;
$options_in{'debug'} = undef;

END {
    unlink @{$tempfiles};
}

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

    #--------------------------------------------------------------------------
    # Translate option names into local language
    my $lh = Idval::I18N->idv_get_handle() || die "Can't get language handle.";
    $self->{LH} = $lh;

    foreach my $opt_name (@standard_options_in)
    {
        $option_names{$opt_name} = $lh->idv_getkey('options', $opt_name);
        push(@standard_options, $option_names{$opt_name});
    }

    foreach my $opt_name (keys %options_in)
    {
        $option_names{$opt_name} = $lh->idv_getkey('options', $opt_name);
        $options{$option_names{$opt_name}} = $options_in{$opt_name};
    }
    #print "Standard options are: ", join("\n", @standard_options), "\n";
    #print "options are: ", Dumper(\%options);
    #--------------------------------------------------------------------------

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
    my $logger_args = Idval::Common::mkargref(
        'level' => $options{$option_names{'verbose'}} - $options{$option_names{'quiet'}},
        defined($options{$option_names{'debug'}}) ? ('debugmask' => $options{$option_names{'debug'}}) : ('', ''),
        $options{$option_names{'development'}} ? ('show_trace' => 1, 'show_time' => 1) : ('', ''),
        'log_out' => $options{$option_names{'log_out'}},
        'print_to' => $options{$option_names{'print_to'}},
        'xml' => $options{$option_names{'xml'}},
        'optimize' => $options{$option_names{'optimize'}},
        );

    Idval::Logger::re_init($logger_args);
    $log = Idval::Common::get_logger();

    # Set up a common location for help info
    my $help_info = Idval::Help->new();
    Idval::Common::register_common_object('help_file', $help_info);

    #$log->str("Idval startup");

    #pod2usage(-verbose => 0)  if ($getopts{'help'});
    #pod2usage(-verbose => 2)  if ($getopts{'man'});
    if ($options{'Version'})
    {
        idv_print("Idval version [_1]\n", $VERSION);
        idv_print("Copyright (C) 2008-2009 Bob Forgey\n");
        idv_print("\nIdval comes with ABSOLUTELY NO WARRANTY.  This is free software, and you\n");
        idv_print("are welcome to redistribute it under certain conditions.  See the GNU\n");
        idv_print("General Public Licence for details.\n");
        exit 0;
    }

    my $real_lib_top = Idval::Common::get_top_dir('lib');
    my $data_dir = Idval::Common::get_top_dir('Data');
    unshift(@INC, $real_lib_top);
    unshift(@INC, Idval::Common::get_top_dir());

    # Tell the system to use the regular filesystem services (i.e., not the unit-testing version)
    Idval::ServiceLocator::provide('io_type', 'FileSystem');

    #verbose("option list: [_1]", Dumper(\%options));
    verbose("Looking for: [_1]\n", Idval::Ui::get_sysconfig_file($data_dir));

    my $sysconfig_file  = $options{$option_names{'sysconfig'}} || Idval::Ui::get_sysconfig_file($data_dir);
    my $userconfig_file = $options{$option_names{'userconfig'}} || Idval::Ui::get_userconfig_file($data_dir);
    verbose("sysconfig is: \"[_1]\", userconfig is \"[_2]\"\n", $sysconfig_file, $userconfig_file);

    my $config = Idval::Config->new($sysconfig_file);
    $config->add_file($userconfig_file) if $userconfig_file;

# XXX This really should be done during installation ? Let's try it this way for now
    # Is this the first time through?
    if (not $config->value_exists('data_store', {config_group => 'idval_settings'}))
    {
        require Idval::FirstTime;
        my $ft = Idval::FirstTime->new($config);
        my $cfgfile = $ft->setup();
        $config->add_file($cfgfile);
    }
    #print "data_store is: ", $config->get_single_value('data_store', {config_group => 'idval_settings'}), "\n";

    Idval::Common::register_common_object('tempfiles', $tempfiles);
    $self->{CONFIG} = $config;
    Idval::Common::register_common_object('config', $self->config());
    $self->{PROVIDERS} = Idval::ProviderMgr->new($config);
    Idval::Common::register_common_object('providers', $self->providers());
    $self->{TYPEMAP} = Idval::TypeMap->new($self->providers());
    Idval::Common::register_common_object('typemap', $self->typemap());

    # This call will set the current id3_encoding
    $self->{DATASTORE} = Idval::Collection->new({contents => '', source => 'blank'});

    $self->{REMAINING_ARGS} = [@other_args];
    chatty("Remaining args: <[_1]>\n", join(", ", @{$self->{REMAINING_ARGS}}));
    return;
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
use Idval::Common;
use Idval::Logger qw(chatty fatal);
use Data::Dumper;

our $AUTOLOAD;

# We should only get here if the command has not (previously) been defined.
sub AUTOLOAD  ## no critic (RequireFinalReturn)
{
    my $rtn = $AUTOLOAD;
    my $name;
    ($name = $rtn) =~ s/^.*::([^:]+)$/$1/;

    return if $name =~ m/^[[:upper:]]+$/;

    chatty("In autoload, checking \"[_1]\"\n", $name);
    my $providers = Idval::Common::get_common_object('providers');
    fatal("ERROR: Command \"$rtn\" called too early\n") unless defined $providers;

    chatty("In autoload; rtn is \"[_1]\"\n", $rtn);

    my $subr = $providers->get_provider('command', $name, 'NULL');
    no strict 'refs';
    *$rtn = sub {$subr->main(@_);};

    goto &$rtn;

    use strict;
}

1;
