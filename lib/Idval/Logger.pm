package Idval::Logger;

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
use Data::Dumper;
use IO::Handle;
use Carp qw(croak cluck confess);
use POSIX qw(strftime);

use Idval::Constants;

$Carp::CarpLevel = 1;

my $lo;
my $lo_begin;
my @warnings;
our $depth = 0;

autoflush STDOUT 1;

my %level_to_name = (-1 => 'SILENT',
                     0  => 'QUIET',
                     1  => 'INFO',
                     2  => 'VERBOSE',
                     3  => 'CHATTY',
    );

my %DEBUG_MACROS = 
    ( 'DBG_STARTUP' => [qw(ProviderMgr)],
      'DBG_PROCESS' => [qw(Common Converter DoDots Provider ServiceLocator)],
      'DBG_CONFIG'  => [qw(Config Select Validate)],
      'DBG_PROVIDERS' => [qw(ProviderMgr)],
      'DBG_FOR_UNIT_TEST0' => [qw(Common DBG_STARTUP DoDots)],
      'DBG_FOR_UNIT_TEST1' => [qw(Common DBG_FOR_UNIT_TEST1 DoDots)],
    );

END {
    if (@warnings and $lo)
    {
        $lo->_log({level => $SILENT, debugmask => 0}, "The following warnings occurred:\n");
        $lo->_log({level => $SILENT, debugmask => 0}, @warnings);
    }
    }

sub safe_get
{
    my $argref = shift;
    my $key = shift;
    my $default = shift;
    #print STDERR "\n--------\nargref: ", Dumper($argref);
    #print STDERR "safe_get: key is \"$key\"\n";
    #print STDERR "safe_get: exists key is \"", exists($argref->{$key}), "\"\n";
    #print STDERR "safe_get: argref->key is: \"", $argref->{$key}, "\"\n" if exists($argref->{$key});
    my $retval = !exists $argref->{$key}        ? $default
               : $argref->{$key}                ? $argref->{$key}
               :                                  $default;
    #print STDERR "Returning \"$retval\"\n--------\n\n";
    return $retval;
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

    $self->accessor('LOGLEVEL', exists $argref->{level} ? $argref->{level} : $QUIET);
    #$self->accessor('DEBUGMASK', exists $argref->{debugmask} ? $argref->{debugmask} : $DBG_STARTUP + $DBG_PROCESS);
    $self->accessor('SHOW_TRACE', exists $argref->{show_trace} ? $argref->{show_trace} : 0);
    $self->accessor('SHOW_TIME', exists $argref->{show_time} ? $argref->{show_time} : 0);
    $self->accessor('USE_XML', exists $argref->{xml} ? $argref->{xml} : 0);
    $self->accessor('FROM',  exists $argref->{from} ? $argref->{from} : 'nowhere');

    $self->set_debugmask(exists $argref->{debugmask} ? $argref->{debugmask} : 'DBG_STARTUP+DBG_PROCESS');
    $self->set_fh('LOG_OUT',  safe_get($argref, 'log_out', 'STDOUT'));
    $self->set_fh('PRINT_TO', safe_get($argref, 'print_to', 'STDOUT'));

    $self->{WARNINGS} = ();

    return;
}

sub str
{
    my $self = shift;
    my $title = shift;
    my $io = shift || 'STDERR';

    no strict 'refs';
    print $io "$title\n" if $title;
    print $io "Logger settings:\n";
    printf $io "  log level:  %d\n", $self->accessor('LOGLEVEL');
    printf $io "  debug mask: 0x%0X\n", $self->accessor('DEBUGMASK');
    printf $io "  show trace: %d\n", $self->accessor('SHOW_TRACE');
    printf $io "  show time:  %d\n", $self->accessor('SHOW_TIME');
    printf $io "  use xml:    %d\n", $self->accessor('USE_XML');
    printf $io "  output:     %s\n", $self->accessor('LOG_OUT');
    printf $io "  from:       %s\n", $self->accessor('FROM');
    use strict;
    return;
}

sub set_fh
{
    my $self = shift;
    my $fhtype = shift;
    my $name = shift;
    my $fh;

  NLOG:
    {
        if ($name eq "STDOUT")
        {
            $fh = *STDOUT{IO};
            last NLOG;
        }
        
        if ($name eq "STDERR")
        {
            $fh = *STDERR{IO};
            last NLOG;
        }
        
        undef $fh;
        open($fh, ">&=", $name) || croak "Can't duplicate file descriptor \"$name\" for writing: $!\n"; ## no critic (RequireBriefOpen)
    }

    $self->{$fhtype} = $fh;

    return $fh;
}

sub _walklist {
    my $list = shift;
    my @result;
    local $depth = $depth;

    croak "mask spec contains a recursive macro" if $depth++ > 10;

    foreach my $item (@{$list})
    {
        if ($item =~ m/^DBG_/)
        {
            croak("unrecognized macro \"$item\" requested for debug mask\n") unless exists($DEBUG_MACROS{$item});
            push(@result, _walklist($DEBUG_MACROS{$item}));
        }
        else
        {
            push(@result, $item);
        }
    }
    return @result;
}

sub set_debugmask
{
    my $self = shift;
    my $dbglist = shift;
    my $loglevel = $self->accessor('LOGLEVEL');
    $depth = 0;

    my @modlist = eval {_walklist([split(/\+|,|\s+/, $dbglist)])};
    croak "Error: For debug mask spec \"$dbglist\", $@\n" if $@;
    my ($a, $b, $c, $d);
    my @rev;
    my $quad;
    my %modules = ();

    foreach my $item (@modlist)
    {
        @rev = reverse split(/::/, $item);
        #print STDERR "rev is: <", join(',', @rev), ">\n";
        push(@rev, qw(* * * *)); # Make sure we have at least four items
        $quad = join('::', @rev[0..3]); # Exactly four
        $quad =~ s/\*/\.\*\?/g;
        $modules{$quad} = $loglevel;
    }

    $self->{MODULE_HASH} = \%modules;
    # Now make a regular expression to match packages
    my $mod_re = '^(' . join('|', keys %modules) . ')$';
    $self->{MODULE_REGEXP} = qr/$mod_re/; # Don't compile it; it will never change (even if reassigned)

    #print STDERR "module_regexp is: \"$self->{MODULE_REGEXP}\"\n";
    return sort keys %modules;
}

sub get_debugmask
{
    my $self = shift;

    return $self->{MODULE_HASH};
}

sub add_to_debugmask
{
    my $self = shift;
    my $modspec = shift;

    my @rev = reverse split(/::/, $modspec);
    #print STDERR "rev is: <", join(',', @rev), ">\n";
    push(@rev, qw(* * * *)); # Make sure we have at least four items
    my $quad = join('::', @rev[0..3]); # Exactly four
    $quad =~ s/\*/\.\*\?/g;

    $self->{MODULE_HASH}->{$quad} = $self->accessor('LOGLEVEL');
    my $mod_re = '^(' . join('|', keys %{$self->{MODULE_HASH}}) . ')$';
    $self->{MODULE_REGEXP} = qr/$mod_re/; # Don't compile it; it will never change (even if reassigned)

    return;
}

sub remove_from_debugmask
{
    my $self = shift;
    my $modspec = shift;

    my @rev = reverse split(/::/, $modspec);
    #print STDERR "rev is: <", join(',', @rev), ">\n";
    push(@rev, qw(* * * *)); # Make sure we have at least four items
    my $quad = join('::', @rev[0..3]); # Exactly four
    $quad =~ s/\*/\.\*\?/g;

    delete $self->{MODULE_HASH}->{$quad} if exists $self->{MODULE_HASH}->{$quad};
    my $mod_re = '^(' . join('|', keys %{$self->{MODULE_HASH}}) . ')$';
    $self->{MODULE_REGEXP} = qr/$mod_re/; # Don't compile it; it will never change (even if reassigned)

    return;
}

sub accessor
{
    my $self = shift;
    my $key = shift;
    my $value = shift;

    $self->{VARS}->{$key} = $value if defined($value);
    return defined $self->{VARS}->{$key} ? $self->{VARS}->{$key} : 0;
}

sub is_chatty
{
    my $self = shift;
    my $level = shift;

    return $self->ok($CHATTY);
}

sub log_level_is_over
{
    my $self = shift;
    my $level = shift;

    return $self->accessor('LOGLEVEL') > $level;
}

sub log_level_is_under
{
    my $self = shift;
    my $level = shift;

    return $self->accessor('LOGLEVEL') < $level;
}

sub log_level_is_between
{
    my $self = shift;
    my $level_low = shift;
    my $level_high = shift;

    return ($self->accessor('LOGLEVEL') > $level_low) and ($self->accessor('LOGLEVEL') < $level_high);
}

sub ok
{
    my $self = shift;
    my $level = shift;

    return $level <= $self->accessor('LOGLEVEL');
}

sub _pkg_matches
{
    my $self = shift;
    my $pkg = shift;
    my @rev = reverse split(/::/, $pkg);
    #print STDERR "rev is: <", join(',', @rev), ">\n";
    push(@rev, qw(* * * *)); # Make sure we have at least four items
    my $quad = join('::', @rev[0..3]); # Exactly four

    $quad =~ $self->{MODULE_REGEXP};

    my $match = $1;
    #print STDERR "pm: for \"$quad\", got \"$match\"\n";

    return defined($match);
}

sub _log
{
    my $self = shift;
    my $argref = shift;

    my $fh = $self->{LOG_OUT};
    my $level = $argref->{level};
    my $decorate = exists($argref->{decorate}) ? $argref->{decorate} : 1;
    my $call_depth = exists($argref->{call_depth}) ? $argref->{call_depth} : 1;
    my $isquery = exists($argref->{query}) ? $argref->{query} : 0;
    my $from = exists($argref->{from}) ? $argref->{from} : $self->accessor("FROM");
    my $prepend = '';

    my $package = caller($call_depth);
    my $module  = (split(/::/, $package))[-1];
    my ($a, $b, $c, $d) = reverse split(/::/, $package);
    # So we can override
    #my $debugmask_ok = exists($argref->{debugmask_ok}) ? $argref->{debugmask_ok} : exists($self->{DEBUGMASK}->{$module});
    my $debugmask_ok = exists($argref->{debugmask_ok}) ? $argref->{debugmask_ok} : $self->_pkg_matches($package);

    if ($isquery)
    {
        $debugmask_ok = 1;
        $level = $SILENT;
        $decorate = 0;
    }

    return unless $debugmask_ok;
    return unless $self->ok($level);

    if ($self->accessor('USE_XML'))
    {
        my $type = $isquery ? 'QUERY' : 'MSG';
        print "<LOGMESSAGE>\n";
        print "<LEVEL>", $level_to_name{$level}, "</LEVEL>\n";
        print "<SOURCE>$package</SOURCE>\n" if $decorate;
        print "<TIME>", strftime("%y-%m-%d %H:%M:%S ", localtime), "</TIME>\n" if $decorate;
        print "<$type>", @_, "</$type>\n";
        print "</LOGMESSAGE>\n";
    }
    else
    {
        return unless $fh;

        if ($decorate)
        {
            my $time = $self->accessor('SHOW_TIME') ? strftime("%y-%m-%d %H:%M:%S ", localtime) : '';
            $prepend = $time . $package . ': ';
        }

        print $fh ($prepend, @_);
    }

    if ($isquery)
    {
        my $ans;
        $ans = <>;
        if( defined $ans ) {
            chomp $ans;
        }
        else { # user hit ctrl-D
            $self->silent_q({debugmask=>1}, "\n");
        }

        return $ans;
    }
}

sub silent
{
    my $self = shift;
    return $self->_log({level => $SILENT}, @_);
}

sub silent_q
{
    my $self = shift;
    return $self->_log({level => $SILENT, decorate => 0}, @_);
}

sub quiet
{
    my $self = shift;
    return $self->_log({level => $QUIET}, @_);
}

sub info
{
    my $self = shift;
    return $self->_log({level => $INFO}, @_);
}

sub info_q
{
    my $self = shift;
    return $self->_log({level => $INFO, decorate => 0}, @_);
}

sub verbose
{
    my $self = shift;
    return $self->_log({level => $VERBOSE}, @_);
}

sub chatty
{
    my $self = shift;
    return $self->_log({level => $CHATTY}, @_);
}

sub idv_warn
{
    my $self = shift;
    push(@warnings, join("", @_));
    return $self->_log({level => $QUIET, debugmask_ok => 1}, @_);
}

sub _warn
{
    my $self = shift;

    push(@warnings, join("", @_));
    return $self->_log({level => $QUIET, debugmask_ok => 1, call_depth => 2}, @_);
}

sub fatal
{
    my $self = shift;

    $self->_log({level => $QUIET, debugmask_ok => 1, call_depth => 2}, @_);
    if ($self->accessor('SHOW_TRACE'))
    {
        Carp::confess('Backtrace');
    }
    else
    {
        Carp::croak('fatal error');
    }
}

sub get_warnings
{
    my $self = shift;

    return @warnings;
}

sub make_custom_logger
{
    my $self = shift;
    my $argref = shift;

    #print STDERR "Making custom logger with: ", Dumper($argref);
    return sub {
        return $self->_log($argref, @_)
    }
}

# Not for general use - should only be used (once) by the driver program, after
# enough options are known.

sub initialize_logger
{
    my $argref = shift;

    $lo = new Idval::Logger($argref);
    return;
}

sub get_logger
{
    return $lo || $lo_begin;
}

BEGIN {
%DEBUG_MACROS = 
    ( 'DBG_STARTUP' => [qw(ProviderMgr)],
      'DBG_PROCESS' => [qw(Common Converter DoDots Provider ServiceLocator)],
      'DBG_CONFIG'  => [qw(Config Select Validate)],
      'DBG_PROVIDERS' => [qw(ProviderMgr)],
      'DBG_FOR_UNIT_TEST0' => [qw(Common DBG_STARTUP DoDots)],
      'DBG_FOR_UNIT_TEST1' => [qw(Common DBG_FOR_UNIT_TEST1 DoDots)],
    );
    $lo_begin = Idval::Logger->new({development => 0,
                             log_out => 'STDERR'});
}

1;
