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
use Memoize qw(memoize flush_cache);

use base qw( Exporter );
our @EXPORT_OK = qw( idv_print silent silent_q quiet info info_q verbose chatty debug idv_warn fatal
                     $L_SILENT $L_QUIET $L_INFO $L_VERBOSE $L_CHATTY $L_DEBUG %level_to_name %name_to_level);
our %EXPORT_TAGS = (vars => [qw($L_SILENT $L_QUIET $L_INFO $L_VERBOSE $L_CHATTY $L_DEBUG %level_to_name %name_to_level)]);

$Carp::CarpLevel = 1;

my $lo;
my $lo_begin;
my @warnings;
our $depth = 0;

autoflush STDOUT 1;

our $L_SILENT      = -1;
our $L_QUIET       = 0;
our $L_INFO        = 1;
our $L_VERBOSE     = 2;
our $L_CHATTY      = 3;
our $L_DEBUG       = 4;

our %level_to_name;
our %name_to_level;

# use 'our' instead of 'my' for unit tests
our %DEBUG_MACROS;

END {
    if (@warnings and $lo)
    {
        $lo->_log({level => $L_SILENT, debugmask => 0}, "The following warnings occurred:\n");
        $lo->_log({level => $L_SILENT, debugmask => 0}, @warnings);
    }
    }

sub safe_get
{
    my $argref = shift;
    my $key = shift;
    my $default = shift;
    my $retval = !exists $argref->{$key}        ? $default
               : $argref->{$key}                ? $argref->{$key}
               :                                  $default;
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

    my $initial_dbg = exists($ENV{IDV_DEBUGMASK}) ? $ENV{IDV_DEBUGMASK} : 'DBG_STARTUP DBG_PROCESS Command::*';
    my $initial_lvl = exists($ENV{IDV_DEBUGLEVEL}) ? $ENV{IDV_DEBUGLEVEL} : $L_QUIET;

    $self->accessor('LOGLEVEL', exists $argref->{level} ? $argref->{level} : $initial_lvl);
    $self->set_debugmask(exists $argref->{debugmask} ? $argref->{debugmask} : $initial_dbg);

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
    my $title = shift;
    my $io = shift || 'STDERR';

    no strict 'refs';
    print $io "$title\n" if $title;
    print $io "Logger settings:\n";
    printf $io "  log level:  %d\n", $self->accessor('LOGLEVEL');
    printf $io "  show trace: %d\n", $self->accessor('SHOW_TRACE');
    printf $io "  show time:  %d\n", $self->accessor('SHOW_TIME');
    printf $io "  use xml:    %d\n", $self->accessor('USE_XML');
    confess "No log_out?" unless defined($self->accessor('LOG_OUT'));
    printf $io "  output:     %s\n", $self->accessor('LOG_OUT');
    printf $io "  from:       %s\n", $self->accessor('FROM');
    printf $io "  debug mask: \n",   $self->str_debugmask('              ');
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
    $self->{VARS}->{$fhtype} = $fh;

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

    flush_cache('_pkg_matches');

    if (ref $dbglist eq 'HASH')
    {
        # We are restoring it
        $self->{MODULE_HASH} = $dbglist;

        # Now make a regular expression to match packages
        my $mod_re = '^((' . join(')|(', keys %{$dbglist}) . '))$';
        $self->{MODULE_REGEXP} = qr/$mod_re/; # Don't compile it; it will never change (even if reassigned)
        return sort keys %{$dbglist};
    }

    my $loglevel = $self->accessor('LOGLEVEL');
    $depth = 0;

    my @modlist = eval {_walklist([split(/,|\s+/, $dbglist)])};
    croak "Error: For debug mask spec \"$dbglist\", $@\n" if $@;
    #print STDERR "modlist from walkies is: ", join(",", @modlist), "\n";
    my @rev;
    my $quad;
    my %modules = exists $self->{MODULE_HASH} ? %{$self->{MODULE_HASH}} : ();

    my @replacements;
    my @additions;
    my @removals;
    # First, split the list into replacements, additions, and removals

    foreach my $item (@modlist)
    {
        push(@removals, $1), next if $item =~ m/^-(.*)$/;
        push(@additions, $1), next if $item =~ m/^\+(.*)$/;
        push(@replacements, $item);
    }

    #print STDERR "Replacements: <", join(',', @replacements), "\n";
    #print STDERR "Additions: <", join(',', @additions), ">\n";
    #print STDERR "Removals: <", join(',', @removals), ">\n";
    # If we have any replacements, do that
    if (@replacements)
    {
        %modules = ();
        foreach my $mod (@replacements)
        {
            # split module name and log level (if present). Also remove colon from log level.
            my ($item, $level) = ($mod =~ m/^(.*?)(?::(\d+))?$/);
            #print STDERR "rep: from \"$mod\", got \"$item\" and ", defined($level) ? "\"$level\"" : "undef", "\n";
            @rev = reverse split(/::/, $item);
            #print STDERR "rev is: <", join(',', @rev), ">\n";
            push(@rev, qw(* * * *)); # Make sure we have at least four items
            $quad = join('::', @rev[0..3]); # Exactly four
            $quad =~ s/\*/\.\*\?/g;

            $modules{$quad}->{LEVEL} = defined($level) ? $level : $self->accessor('LOGLEVEL');
            $modules{$quad}->{STR} = $item;
        }
    }

    # Do additions
    if (@additions)
    {
        #print STDERR "additions: modules is: ", Dumper(\%modules);
        foreach my $mod (@additions)
        {
            # split module name and log level (if present). Also remove colon from log level.
            my ($item, $level) = ($mod =~ m/^(.*?)(?::(\d+))?$/);
            #print STDERR "add: from \"$mod\", got \"$item\" and ", defined($level) ? "\"$level\"" : "undef", "\n";
            my @rev = reverse split(/::/, $item);
            push(@rev, qw(* * * *)); # Make sure we have at least four items
            my $quad = join('::', @rev[0..3]); # Exactly four
            $quad =~ s/\*/\.\*\?/g;
            #print STDERR "additions: rev is: <", join(',', @rev), ">, quad is: \"$quad\"\n";

            $modules{$quad}->{LEVEL} = defined($level) ? $level : $self->accessor('LOGLEVEL');
            $modules{$quad}->{STR} = $item;
        }
    }

    # Do removals
    if (@removals)
    {
        #print STDERR "Removals: modules is: ", Dumper(\%modules);
        foreach my $mod (@removals)
        {
            # Really, we don't need to extract the log level here, but for symmetry...
            my ($item, $level) = ($mod =~ m/^(.*?)(?::(\d+))?$/);
            #print STDERR "rem: from \"$mod\", got \"$item\" and ", defined($level) ? "\"$level\"" : "undef", "\n";
            my @rev = reverse split(/::/, $item);
            push(@rev, qw(* * * *)); # Make sure we have at least four items
            my $quad = join('::', @rev[0..3]); # Exactly four
            $quad =~ s/\*/\.\*\?/g;
            #print STDERR "removals: rev is: <", join(',', @rev), ">, quad is: \"$quad\"\n";

            delete $modules{$quad} if exists $modules{$quad};
        }
    }

    $self->{MODULE_HASH} = \%modules;

    my @regexlist = keys %modules;
    $self->{MODULE_LIST} = \@regexlist;
    # Now make a regular expression to match packages
    my $mod_re = '^(?:(' . join(')|(', @regexlist) . '))$';
    $self->{MODULE_REGEXP} = qr/$mod_re/i; # Don't compile it; it will never change (even if reassigned)

    #print STDERR "module_regexp is: \"$self->{MODULE_REGEXP}\"\n";
    #print STDERR "module_hash: ", Dumper($self->{MODULE_HASH});
    #print STDERR "Returning: ", join(", ", sort keys %modules), "\n";
    return \%modules;
}

sub get_debugmask
{
    my $self = shift;
    my $dbglist = shift;
    my %retval = (%{$self->{MODULE_HASH}});

    $self->set_debugmask($dbglist) if defined($dbglist);
    return \%retval;
}

sub str_debugmask
{
    my $self = shift;
    my $lead = shift;
    my $lead2 = shift || "\n";

    #my $str = $lead . join($lead2 . $lead, sort keys %{$self->{MODULE_HASH}});
    my $str = Dumper($self->{MODULE_HASH});

    return $str;
}

sub accessor
{
    my $self = shift;
    my $key = shift;
    my $value = shift;
    my $retval = $self->{VARS}->{$key};

    $self->{VARS}->{$key} = $value if defined($value);
    return $retval;
}

sub is_chatty
{
    my $self = shift;
    my $level = shift;

    return $self->ok($L_CHATTY);
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

    confess "level is undef" unless defined($level);
    confess "loglevel is undef" unless defined($self->accessor('LOGLEVEL'));
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

    #my @foo;
    #print STDERR "Matching \"$quad\" to \"", $self->{MODULE_REGEXP}, "\"\n";
    #@foo = ($quad =~ m/$self->{MODULE_REGEXP}/);
    #print STDERR "pm Results are: ", Dumper(\@foo);
    my $result = $quad =~ m/$self->{MODULE_REGEXP}/;
    # Use @- to find which exp matched
    #print STDERR $result ? "Got match (result is \"$result\"\n" : "no match\n";
    #print STDERR "match id: ", $#-, "\n";
    #print STDERR "match module: ", ${$self->{MODULE_LIST}}[$#- - 1], "\n";
    #print STDERR "-: ", Dumper(\@-);
    #print STDERR "+: ", Dumper(\@+);

    my $matched_module = ${$self->{MODULE_LIST}}[$#- - 1];
    $result += 0;               # Force it to be numeric
    my $loglevel = $result ? $self->{MODULE_HASH}->{$matched_module}->{LEVEL} : -99;
    #print STDERR "pm: for $pkg, returning ($result, $loglevel)\n";
    return ($result, $loglevel);
}

sub _log
{
    my $self = shift;
    my $call_args = shift;

    # If caller passes in an argref as the first parameter, allow override of the defaults by the caller
    my %caller_args;
    %caller_args = %{$_[0]}, shift if ref $_[0] eq 'HASH';

    my %argref = (
        decorate => 1,
        call_depth => 1,
        query => 0,
        package => '',
        force_match => 0,

        %{$call_args},          # Logger call customization
        %caller_args,           # Caller customization
        );


    my $level = $argref{level};
    my $isquery = $argref{query};
    my $force_match = $argref{force_match} || $isquery;

    # The caller can supply a package name. Otherwise, determine it automatically
    my $package = $argref{package} ? $argref{package} : caller($argref{call_depth});
    my ($got_match, $l_level) = $self->_pkg_matches($package);
    my $debugmask_ok = $force_match || $got_match;

    return if !(($level <= $l_level) or $isquery or $force_match);
    return if !$debugmask_ok;

    my $fh = $self->{LOG_OUT};
    my $decorate = $argref{decorate};

    my $prepend = '';

    #print STDERR "level: $level, deco: $decorate, package: $package, debugmask_ok: $debugmask_ok\n";
    #print STDERR "modlist: ", Dumper($self->{MODULE_HASH}) if $package =~ m/Validate/;
    #print STDERR "Log: should print\n";
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

# Really, a replacement for 'print'
sub idv_print
{
    return get_logger()->_log({level => $L_SILENT, decorate => 0, force_match => 1}, @_);
}

sub silent
{
    return get_logger()->_log({}, @_);
}

sub silent_q
{
    return get_logger()->_log({level => $L_SILENT, decorate => 0}, @_);
}

sub quiet
{
    return get_logger()->_log({level => $L_QUIET}, @_);
}

sub info
{
    return get_logger()->_log({level => $L_INFO}, @_);
}

sub info_q
{
    return get_logger()->_log({level => $L_INFO, decorate => 0}, @_);
}

sub verbose
{
    return get_logger()->_log({level => $L_VERBOSE}, @_);
}

sub chatty
{
    return get_logger()->_log({level => $L_CHATTY}, @_);
}

sub debug
{
    return get_logger()->_log({level => $L_DEBUG}, @_);
}

sub idv_warn
{
    push(@warnings, join("", @_));
    return get_logger()->_log({level => $L_QUIET, force_match => 1}, @_);
}

sub _warn
{
    my $self = shift;

    push(@warnings, join("", @_));
    return $self->_log({level => $L_QUIET, force_match => 1, call_depth => 2}, @_);
}

sub fatal
{
    get_logger()->_log({level => $L_QUIET, force_match => 1, call_depth => 2}, @_);
    if (get_logger()->accessor('SHOW_TRACE'))
    {
        Carp::confess(@_);
    }
    else
    {
        Carp::croak(@_);
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

    if (ref $argref eq 'Idval::Logger')
    {
        $lo = $argref;
    }
    else
    {
        $lo = new Idval::Logger($argref);
    }

    return;
}

sub get_logger
{
    return $lo || $lo_begin;
}

BEGIN {
    $L_SILENT      = -1;
    $L_QUIET       = 0;
    $L_INFO        = 1;
    $L_VERBOSE     = 2;
    $L_CHATTY      = 3;
    $L_DEBUG       = 4;

    %DEBUG_MACROS =
        ( 'DBG_STARTUP' => [qw(ProviderMgr)],
          'DBG_PROCESS' => [qw(Common Converter DoDots Provider ServiceLocator)],
          'DBG_CONFIG'  => [qw(Config Select Validate)],
          'DBG_PROVIDERS' => [qw(ProviderMgr)],
        );

    %level_to_name = (-1 => 'silent',
                      0  => 'quiet',
                      1  => 'info',
                      2  => 'verbose',
                      3  => 'chatty',
                      4  => 'debug',
    );

    foreach my $key (keys %level_to_name)
    {
        $name_to_level{$level_to_name{$key}} = $key;
    }

    memoize('_pkg_matches');

    $lo_begin = Idval::Logger->new({development => 0,
                             log_out => 'STDERR'});
}

1;
