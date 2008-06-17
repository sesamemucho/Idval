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

autoflush STDOUT 1;

my %level_to_name = (-1 => 'SILENT',
                     0  => 'QUIET',
                     1  => 'INFO',
                     2  => 'VERBOSE',
                     3  => 'CHATTY',
    );

END {
    if (@warnings)
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

    return !exists $argref->{key}        ? $default
          : $argref->{key}               ? $argref->{key}
          :                                $default;
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
    $self->accessor('DEBUGMASK', exists $argref->{debugmask} ? $argref->{debugmask} : $DBG_STARTUP + $DBG_PROCESS);
    $self->accessor('SHOW_TRACE', exists $argref->{show_trace} ? $argref->{show_trace} : 0);
    $self->accessor('SHOW_TIME', exists $argref->{show_time} ? $argref->{show_time} : 0);
    $self->accessor('USE_XML', exists $argref->{xml} ? $argref->{xml} : 0);
    $self->accessor('FROM',  exists $argref->{from} ? $argref->{from} : 'nowhere');

    $self->set_fh('LOG_OUT',  safe_get($argref, 'log_out', 'STDOUT'));
    $self->set_fh('PRINT_TO', safe_get($argref, 'print_to', 'STDOUT'));

    $self->{WARNINGS} = ();

    return;
}

sub str
{
    my $self = shift;

    print "Logger settings:\n";
    printf "  log level:  %d\n", $self->accessor('LOGLEVEL');
    printf "  debug mask: 0x%0X\n", $self->accessor('DEBUGMASK');
    printf "  show trace: %d\n", $self->accessor('SHOW_TRACE');
    printf "  show time:  %d\n", $self->accessor('SHOW_TIME');
    printf "  use xml:    %d\n", $self->accessor('USE_XML');
    printf "  output:     %s\n", $self->accessor('LOG_OUT');
    printf "  from:       %s\n", $self->accessor('FROM');
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
        if ($name eq "STDOUT" or $name eq "STDERR")
        {
            $fh = *STDOUT{IO};
            last NLOG;
        }
        
        undef $fh;
        open($fh, ">&=", $name) || croak "Can't duplicate file descriptor \"$name\" for writing: $!\n"; ## no critic (RequireBriefOpen)
    }

    $self->{$fhtype} = $fh;

    return $fh;
}

sub accessor
{
    my $self = shift;
    my $key = shift;
    my $value = shift;

    $self->{$key} = $value if defined($value);
    return defined $self->{$key} ? $self->{$key} : 0;
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

sub _log
{
    my $self = shift;
    my $argref = shift;

    my $fh = $self->{LOG_OUT};
    my $level = $argref->{level};
    my $debugmask = $argref->{debugmask};
    my $decorate = exists($argref->{decorate}) ? $argref->{decorate} : 1;
    my $call_depth = exists($argref->{call_depth}) ? $argref->{call_depth} : 1;
    my $isquery = exists($argref->{query}) ? $argref->{query} : 0;
    my $prepend = '';

    if ($isquery)
    {
        $debugmask = $DBG_ALL;
        $level = $SILENT;
        $decorate = 0;
    }
    
    if (($self->accessor("FROM") eq 'BARFO') || ($_[0] =~ m/Well/))
    {
        print "debugmask: $debugmask; stored value: $self->{DEBUGMASK}\n";
        print "level: $level; stored value: $self->{LOGLEVEL}\n";
    }

    return unless $debugmask & $self->{DEBUGMASK};

    if ($self->{USE_XML})
    {
        my $type = $isquery ? 'QUERY' : 'MSG';
        print "<LOGMESSAGE>\n";
        print "<LEVEL>", $level_to_name{$level}, "</LEVEL>\n";
        print "<SOURCE>" . caller($call_depth) . "</SOURCE>\n" if $decorate;
        print "<TIME>", strftime("%y-%m-%d %H:%M:%S ", localtime), "</TIME>\n" if $decorate;
        print "<$type>", @_, "</$type>\n";
        print "</LOGMESSAGE>\n";
    }
    else
    {

        if ($decorate)
        {
            my $time = $self->{SHOW_TIME} ? strftime("%y-%m-%d %H:%M:%S ", localtime) : '';
            $prepend = $time . caller($call_depth) . ': ';
        }

        print $fh ($prepend, @_) if ($fh and $self->ok($level));
    }

    if ($isquery)
    {
        my $ans;
        $ans = <>;
        if( defined $ans ) {
            chomp $ans;
        }
        else { # user hit ctrl-D
            $self->silent_q({debugmask=>$DBG_ALL}, "\n");
        }

        return $ans;
    }
}

sub silent
{
    my $self = shift;
    my $dbgmask = shift;

    return $self->_log({level => $SILENT, debugmask => $dbgmask}, @_);
}

sub silent_q
{
    my $self = shift;
    my $dbgmask = shift;

    return $self->_log({level => $SILENT, decorate => 0, debugmask => $dbgmask}, @_);
}

sub quiet
{
    my $self = shift;
    my $dbgmask = shift;
    return $self->_log({level => $QUIET, debugmask => $dbgmask}, @_);
}

sub info
{
    my $self = shift;
    my $dbgmask = shift;
    return $self->_log({level => $INFO, debugmask => $dbgmask}, @_);
}

sub info_q
{
    my $self = shift;
    my $dbgmask = shift;

    return $self->_log({level => $INFO, decorate => 0, debugmask => $dbgmask}, @_);
#     return unless $dbgmask & $self->{DEBUGMASK};
#     print $self->{INFO_OUT} (@_) if $self->ok($INFO);
}

sub verbose
{
    my $self = shift;
    my $dbgmask = shift;
    return $self->_log({level => $VERBOSE, debugmask => $dbgmask}, @_);
}

sub chatty
{
    my $self = shift;
    my $dbgmask = shift;
    return $self->_log({level => $CHATTY, debugmask => $dbgmask}, @_);
}

sub idv_warn
{
    my $self = shift;
    push(@warnings, join("", @_));
    return $self->_log({level => $QUIET, debugmask => $DBG_ALL}, @_);
}

sub _warn
{
    my $self = shift;

    push(@warnings, join("", @_));
    return $self->_log({level => $QUIET, debugmask => $DBG_ALL, call_depth => 2}, @_);
}

sub fatal
{
    my $self = shift;

    $self->_log({level => $QUIET, debugmask => $DBG_ALL, call_depth => 2}, @_);
    if ($self->{SHOW_TRACE})
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

    #print "Making custom logger with: ", Dumper($argref);
    return sub {
        return $self->_log($argref, @_)
    }
}

# Not for general use - should only be used (once) by the driver program, after
# enough options are known.

sub initialize_logger
{
    #print "Got ", join(':', @_), "\n";
    $lo = new Idval::Logger({@_});

    return;
}

sub get_logger
{
    return $lo || $lo_begin;
}

BEGIN {
    $lo_begin = Idval::Logger->new({development => 0,
                             log_out => 'STDOUT'});
}

1;
