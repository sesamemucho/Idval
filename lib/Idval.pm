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

use strict;
use warnings;
use 5.006;

use Getopt::Long;
use Data::Dumper;
use File::Spec;
use Cwd;

use Idval::Logger qw(verbose chatty);
use Idval::ServiceLocator;
use Idval::Ui;
use Idval::Config;
use Idval::ProviderMgr;
use Idval::FileIO;
use Idval::Common;
use Idval::Help;

my @standard_options;
my %options;
our $VERSION;
our $AUTOLOAD;  ## no critic (ProhibitPackageVars)
my $log;
my $tempfiles = [];

local $| = 1;

$VERSION = '0.7.0';

@standard_options =
    (
     'help',
     'man',
     'Version',
#     'input=s',
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
     'debug=s',
     'development',
     'log_out=i',
    );

# Set defaults
$options{'help'} = '';
$options{'man'} = '';
$options{'version'} = '';
#$options{'input'} = '';
$options{'output'} = '';
$options{'store'} = 1;
$options{'sysconfig'} = '';
$options{'userconfig'} = '';
$options{'no-run'} = 0;
$options{'xml'} = 0;
$options{'verbose'} = 1;
$options{'quiet'} = 0;
#$options{'debug'} = undef;
$options{'development'} = 0;
$options{'log_out'} = '';
$options{'print_to'} = '';

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

    #print "Idval: realargv: ", Dumper(\@realargv);
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
        'level' => $options{'verbose'} - $options{'quiet'},
        defined($options{'debug'}) ? ('debugmask' => $options{'debug'}) : ('', ''),
        $options{'development'} ? ('show_trace' => 1, 'show_time' => 1) : ('', ''),
        'log_out' => $options{'log_out'},
        'print_to' => $options{'print_to'},
        'xml' => $options{'xml'},
        );

    Idval::Logger::initialize_logger($logger_args);
    $log = Idval::Common::get_logger();

    # Set up a common location for help info
    my $help_info = Idval::Help->new();
    Idval::Common::register_common_object('help_file', $help_info);

    $self->set_pod_input();

    #$log->str("Idval startup");

    #pod2usage(-verbose => 0)  if ($getopts{'help'});
    #pod2usage(-verbose => 2)  if ($getopts{'man'});
    #print_version()           if ($getopts{'version'});

    my $real_lib_top = Idval::Common::get_top_dir('lib');
    my $data_dir = Idval::Common::get_top_dir('Data');
    unshift(@INC, $real_lib_top);
    unshift(@INC, Idval::Common::get_top_dir());

    # Tell the system to use the regular filesystem services (i.e., not the unit-testing version)
    Idval::ServiceLocator::provide('io_type', 'FileSystem');

    verbose("option list:", Dumper(\%options));
    verbose("Looking for: ", Idval::Ui::get_sysconfig_file($data_dir), "\n");

    my $sysconfig_file  = $options{'sysconfig'} || Idval::Ui::get_sysconfig_file($data_dir);
    my $userconfig_file = $options{'userconfig'} || Idval::Ui::get_userconfig_file($data_dir);
    verbose("sysconfig is: \"$sysconfig_file\", userconfig is \"$userconfig_file\"\n");

    my $config = Idval::Config->new($sysconfig_file);
    $config->add_file($userconfig_file) if $userconfig_file;

# XXX This really should be done during installation ? Let's try it this way for now
    # Is this the first time through?
    print "HELLO from Idval\n";
    if (not $config->value_exists('data_store', {config_group => 'idval_settings'}))
    {
        require Idval::FirstTime;
        my $cfgfile = Idval::FirstTime::init($config);
        print "conf: Got \"$cfgfile\"\n";
        exit;
        #$config->add_file($cfgfile);
    }
    print "data_store is: ", $config->get_single_value('data_store', {config_group => 'idval_settings'}), "\n";

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
    chatty("Remaining args: <", join(", ", @{$self->{REMAINING_ARGS}}), ">\n");
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

    #print STDERR "Checking \"$name\"\n";
    chatty("In autoload, checking \"$name\"\n");
    my $providers = Idval::Common::get_common_object('providers');
    fatal("ERROR: Command \"$rtn\" called too early\n") unless defined $providers;

    chatty("In autoload; rtn is \"$rtn\"\n");

    #my $subr = $providers->find_command($name);
    #$subr .= '::main';
    my $subr = $providers->get_provider('command', $name, 'NULL');
    #print STDERR "autoload: subr is: ", Dumper($subr);
    no strict 'refs';
    #*$rtn = $subr;              # For next time, so we don't go through AUTOLOAD again
    *$rtn = sub {$subr->main(@_);};

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

Idval - Toolkit for manipulating files with their metadata.

=head1 SYNOPSIS

=head1 DESCRIPTION

Idval is a tool for manipulating files that contain metadata, such as
mp3, flac, and other music files; jpeg and other exif image files; and
any other kind of files that contain metadata.

Two of the principles behind Idval are: 1) that the authoritative
source for a media file's metadata is the media file itself, and 2)
metadata should be presented in a form that's easy to handle with a
text editor. 

Keep a music collection in lossless FLAC format, and then convert to
OGG or MP3 as needed for use with portable music players.

The name "Idval" came from "ID Validation". Define rules for a valid
set of ID tags, and Idval will show which tags break the rules. Edit
the text file that represents the metadata and use Idval to correct
the bad tags.



Idval works by using "plugins". Idval plugins read metadata from
files, write metadata to files, convert between file formats, and manipulate metadata XXX

=head1 AUTHOR

Bob Forgey <rforgey\@grumpydogconsulting.com>

=cut

EOD
    $help_file->{'main'} = $pod_input;

    return;
}

1;
