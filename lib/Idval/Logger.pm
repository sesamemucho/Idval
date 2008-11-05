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

use base qw( Exporter );
our @EXPORT_OK = qw( idv_print nsilent nsilent_q nquiet ninfo ninfo_q nverbose nchatty debug nidv_warn nfatal 
$L_SILENT $L_QUIET $L_INFO $L_VERBOSE $L_CHATTY $L_DEBUG);
our %EXPORT_TAGS = (vars => [qw($L_SILENT $L_QUIET $L_INFO $L_VERBOSE $L_CHATTY $L_DEBUG)]);

#use Idval::Constants;

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
our $L_DEBUG      = 4;

my %level_to_name = (-1 => 'SILENT',
                     0  => 'QUIET',
                     1  => 'INFO',
                     2  => 'VERBOSE',
                     3  => 'CHATTY',
                     4  => 'DEBUG',
    );

 # use 'our' instead of 'my' for unit tests
our %DEBUG_MACROS = 
    ( 'DBG_STARTUP' => [qw(ProviderMgr)],
      'DBG_PROCESS' => [qw(Common Converter DoDots Provider ServiceLocator)],
      'DBG_CONFIG'  => [qw(Config Select Validate)],
      'DBG_PROVIDERS' => [qw(ProviderMgr)],
    );

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

    $self->set_debugmask(exists $argref->{debugmask} ? $argref->{debugmask} : $initial_dbg);
    $self->accessor('LOGLEVEL', exists $argref->{level} ? $argref->{level} : $initial_lvl);

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

    if (ref $dbglist eq 'HASH')
    {
        # We are restoring it
        $self->{MODULE_HASH} = $dbglist;

        # Now make a regular expression to match packages
        my $mod_re = '^(' . join('|', keys %{$dbglist}) . ')$';
        $self->{MODULE_REGEXP} = qr/$mod_re/; # Don't compile it; it will never change (even if reassigned)
        return sort keys %{$dbglist};
    }

    my $loglevel = $self->accessor('LOGLEVEL');
    $depth = 0;

    my @modlist = eval {_walklist([split(/,|\s+/, $dbglist)])};
    croak "Error: For debug mask spec \"$dbglist\", $@\n" if $@;
    my ($a, $b, $c, $d);
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
        foreach my $item (@replacements)
        {
            @rev = reverse split(/::/, $item);
            #print STDERR "rev is: <", join(',', @rev), ">\n";
            push(@rev, qw(* * * *)); # Make sure we have at least four items
            $quad = join('::', @rev[0..3]); # Exactly four
            $quad =~ s/\*/\.\*\?/g;
            $modules{$quad} = $self->accessor('LOGLEVEL');
        }
    }

    # Do additions
    if (@additions)
    {
        #print STDERR "additions: modules is: ", Dumper(\%modules);
        foreach my $item (@additions)
        {
            my @rev = reverse split(/::/, $item);
            push(@rev, qw(* * * *)); # Make sure we have at least four items
            my $quad = join('::', @rev[0..3]); # Exactly four
            $quad =~ s/\*/\.\*\?/g;
            #print STDERR "additions: rev is: <", join(',', @rev), ">, quad is: \"$quad\"\n";

            $modules{$quad} = $self->accessor('LOGLEVEL');
        }
    }

    # Do removals
    if (@removals)
    {
        #print STDERR "Removals: modules is: ", Dumper(\%modules);
        foreach my $item (@removals)
        {

            my @rev = reverse split(/::/, $item);
            push(@rev, qw(* * * *)); # Make sure we have at least four items
            my $quad = join('::', @rev[0..3]); # Exactly four
            $quad =~ s/\*/\.\*\?/g;
            #print STDERR "removals: rev is: <", join(',', @rev), ">, quad is: \"$quad\"\n";

            delete $modules{$quad} if exists $modules{$quad};
        }
    }

    $self->{MODULE_HASH} = \%modules;

    # Now make a regular expression to match packages
    my $mod_re = '^(' . join('|', keys %modules) . ')$';
    $self->{MODULE_REGEXP} = qr/$mod_re/; # Don't compile it; it will never change (even if reassigned)

    #print STDERR "module_regexp is: \"$self->{MODULE_REGEXP}\"\n";
    #print STDERR "module_hash: ", Dumper($self->{MODULE_HASH});
    #print STDERR "Returning: ", join(", ", sort keys %modules), "\n";
    return sort keys %modules;
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

    my $str = $lead . join($lead2 . $lead, sort keys %{$self->{MODULE_HASH}});

    return $str;
}

# sub add_to_debugmask
# {
#     my $self = shift;
#     my $modspec = shift;

#     my @rev = reverse split(/::/, $modspec);
#     print STDERR "rev is: <", join(',', @rev), ">\n";
#     push(@rev, qw(* * * *)); # Make sure we have at least four items
#     my $quad = join('::', @rev[0..3]); # Exactly four
#     $quad =~ s/\*/\.\*\?/g;

#     $self->{MODULE_HASH}->{$quad} = $self->accessor('LOGLEVEL');
#     my $mod_re = '^(' . join('|', keys %{$self->{MODULE_HASH}}) . ')$';
#     $self->{MODULE_REGEXP} = qr/$mod_re/; # Don't compile it; it will never change (even if reassigned)

#     return;
# }

# sub remove_from_debugmask
# {
#     my $self = shift;
#     my $modspec = shift;

#     my @rev = reverse split(/::/, $modspec);
#     #print STDERR "rev is: <", join(',', @rev), ">\n";
#     push(@rev, qw(* * * *)); # Make sure we have at least four items
#     my $quad = join('::', @rev[0..3]); # Exactly four
#     $quad =~ s/\*/\.\*\?/g;

#     delete $self->{MODULE_HASH}->{$quad} if exists $self->{MODULE_HASH}->{$quad};
#     my $mod_re = '^(' . join('|', keys %{$self->{MODULE_HASH}}) . ')$';
#     $self->{MODULE_REGEXP} = qr/$mod_re/; # Don't compile it; it will never change (even if reassigned)

#     return;
# }

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

    my @foo;
    #print STDERR "Matching \"$quad\" to \"", $self->{MODULE_REGEXP}, "\"\n";
    @foo = ($quad =~ m/$self->{MODULE_REGEXP}/);
    #print STDERR "pm Results are: ", Dumper(\@foo);
    my $result = $quad =~ m/$self->{MODULE_REGEXP}/;
    my $match;
    if ($result)
    {
        $match = $1;
        #print STDERR "pm: modre: \"", $self->{MODULE_REGEXP}, "\"\n" if defined($match);# and $match eq '__NEXT_LINE';
        #print STDERR "pm: for \"$quad\", got \"", defined($match) ? $match : 'undef', "\"\n";
    }
    else
    {
        #print STDERR "no match\n";
        $match = undef;
    }

    return defined($match);
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

    # Try to determine quickly if we should print
    return if !($self->ok($level) or $isquery);

    my $fh = $self->{LOG_OUT};
    my $decorate = $argref{decorate};
    # The caller can supply a package name. Otherwise, determine it automatically
    my $package = $argref{package} ? $argref{package} : caller($argref{call_depth});

    my $prepend = '';
    my $module  = (split(/::/, $package))[-1];
    my ($a, $b, $c, $d) = reverse split(/::/, $package);
    my $debugmask_ok = $argref{force_match} || $self->_pkg_matches($package);

    if ($isquery)
    {
        $debugmask_ok = 1;
        $level = $L_SILENT;
        $decorate = 0;
    }

    #print STDERR "level: $level, deco: $decorate, package: $package, debugmask_ok: $debugmask_ok\n";
    #print STDERR "modlist: ", Dumper($self->{MODULE_HASH}) if $package =~ m/Validate/;
    return unless $debugmask_ok;
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
    my $self = shift;
    return $self->_log({level => $L_SILENT}, @_);
}

sub nsilent
{
    return get_logger()->_log({}, @_);
}

sub silent_q
{
    my $self = shift;
    return $self->_log({level => $L_SILENT, decorate => 0}, @_);
}

sub nsilent_q
{
    return get_logger()->_log({level => $L_SILENT, decorate => 0}, @_);
}

sub quiet
{
    my $self = shift;
    return $self->_log({level => $L_QUIET}, @_);
}

sub nquiet
{
    return get_logger()->_log({level => $L_QUIET}, @_);
}

sub info
{
    my $self = shift;
    return $self->_log({level => $L_INFO}, @_);
}

sub ninfo
{
    return get_logger()->_log({level => $L_INFO}, @_);
}

sub info_q
{
    my $self = shift;
    return $self->_log({level => $L_INFO, decorate => 0}, @_);
}

sub ninfo_q
{
    return get_logger()->_log({level => $L_INFO, decorate => 0}, @_);
}

sub verbose
{
    my $self = shift;
    return $self->_log({level => $L_VERBOSE}, @_);
}

sub nverbose
{
    return get_logger()->_log({level => $L_VERBOSE}, @_);
}

sub chatty
{
    my $self = shift;
    return $self->_log({level => $L_CHATTY}, @_);
}

sub nchatty
{
    return get_logger()->_log({level => $L_CHATTY}, @_);
}

sub debug
{
    return get_logger()->_log({level => $L_DEBUG}, @_);
}

sub idv_warn
{
    my $self = shift;
    push(@warnings, join("", @_));
    return $self->_log({level => $L_QUIET, force_match => 1}, @_);
}

sub nidv_warn
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
    my $self = shift;

    $self->_log({level => $L_QUIET, force_match => 1, call_depth => 2}, @_);
    if ($self->accessor('SHOW_TRACE'))
    {
        Carp::confess('Backtrace');
    }
    else
    {
        Carp::croak('fatal error');
    }
}

sub nfatal
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
    $lo_begin = Idval::Logger->new({development => 0,
                             log_out => 'STDERR'});
}

#      'DBG_FOR_UNIT_TEST0' => [qw(Common DBG_STARTUP DoDots)],
#      'DBG_FOR_UNIT_TEST1' => [qw(Common DBG_FOR_UNIT_TEST1 DoDots)],

1;
