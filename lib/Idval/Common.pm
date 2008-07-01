package Idval::Common;

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
use POSIX;
use Data::Dumper;
use Carp;
use Config;
use File::Spec;
use FindBin;
use Memoize;
use Text::Balanced qw (
                       extract_delimited
                       extract_multiple
                      );

use Idval::Logger;
use Idval::Constants;

my $log = Idval::Logger::get_logger();
our %common_objs;
my @top_dir_path = ();

memoize('mung_path_query');

# #our %providers = ();

# #INIT {$log = Idval::Logger::get_logger();}

# # sub exe_name
# # {
# #     my $file = shift;

# #     if ($^O ne 'VMS')
# #     {
# #         if (!-e $file)
# #         {
# #             $file .= $Config{_exe} unless $file =~ m/$Config{_exe}$/i;
# #         }
# #     }

# #     return $file;
# # }

sub mung_path_query
{
    my $path = shift;
    my $newpath = qx{cygpath -m "$path"};
    $newpath =~ s{[\n\r]+}{}gx;
    return $newpath;
}

# Some progs don't like some kinds of paths
sub mung_path
{
    my $path = shift;

    if ($Config{osname} eq 'cygwin')
    {
        $path =~ s{/cygdrive/(\w)}{$1:}x;
        if ($path =~ m{^/}x)
        {
            $path = mung_path_query($path);
            # Still not right
        }
    }

    return $path;
}

# Some progs don't like some kinds of paths
sub mung_to_unix
{
    my $path = shift;

    # expand tilde
    $path = Idval::Common::expand_tilde($path);

    # mung drive letter
    if ($Config{osname} eq 'cygwin')
    {
        $path =~ s{^(\w):}{/cygdrive/$1}x;
    }

    # Some File::Spec routines get weirded out
    $path =~ s{^//cygdrive}{/cygdrive}x;

    return $path;
}

# Called if user sets the top dir from the command line
sub set_top_dir
{
    @top_dir_path = @_;

    return;
}

sub get_top_dir
{
    my @subdirs = @_;
    my $got_it = 0;

    if (!@top_dir_path)
    {
        foreach my $dir (File::Spec->splitdir($FindBin::RealBin))
        {
            push(@top_dir_path, $dir);
            if($dir eq 'idv')
            {
                $got_it = 1;
                last;
            }
        }

        if ($got_it == 0)
        {
            croak "Couldn't find top directory \"idv\" in $FindBin::RealBin\n";
        }
    }

    return @subdirs ? File::Spec->catdir(@top_dir_path, @subdirs): File::Spec->catdir(@top_dir_path);
}

sub expand_tilde
{
    my $name = shift;

    $name =~ s{^~([^/]*)}{$1 ? (getpwnam($1))[7] : ($ENV{HOME} || $ENV{LOGDIR} || (getpwuid($>))[7])}ex;

    return $name;
}

# This will need to vary depending on the OS
sub quoteme
{
    my $arg = shift;

    return $arg =~ /[^_\.\-=[:alnum:]]/x ? '"' . $arg . '"' : $arg;
}

sub mkarglist
{
    my @retval;
    my $arg;

    foreach my $arg (@_)
    {
        next if !defined($arg);
        next if $arg =~ m/^\s*$/x;
        # Quote only those arguments that have not already been quoted.
        # This may have to change if we can't use double-quotes for all OSes.

        push(@retval, ($arg =~ m{[""]}x) ? $arg : quoteme($arg));
    }

    return @retval;
}

sub run
{
    my $name = shift;
    my $cmdargs = "";
    my $retval;
    my $status = 0;
    my $no_run = get_common_object_hashval('options', 'no-run');

    $cmdargs = join(" ", @_);

    #$name = exe_name($name);
    if ($no_run)
    {
        $log->quiet($DBG_PROCESS, "$name XXX $cmdargs\n");
        return 0;
    }
    else
    {
        $log->verbose($DBG_PROCESS, "\"$name\" XXX $cmdargs\n");
        $retval = qx{"$name" $cmdargs 2>&1};
        $status = $?;
        if ($status)
        {
            $log->quiet($DBG_PROCESS, "Error $status from: \"$name $cmdargs\"\nReturned \"$retval\"\n");
        }
        #elsif (! $log->log_level_is_under($Idval::Logger::DEBUG1))
        #{
        #    $log->debug1("$retval\n");
        #}
        #if ($arrrgs{'-dot'} and $log->log_level_is_between($Idval::Logger::QUIET, $Idval::Logger::VERBOSE))
        #{
        #    Idval::DoDots::dodots($arrrgs{'-dot'});
        #}
    }

    # It's OK for the program to terminate quietly by signal. The user probably typed a control-C
    #$log->fatal("Program terminated: $! (" . WTERMSIG($status) . ")\n") if WIFSIGNALED($status);
    #exit(1) if WIFSIGNALED($status);
    #$retval = WEXITSTATUS($status) if WIFEXITED($status);
    exit(1) if $status and ($status < 256); # probably a signal

    return $status;
}

# Originally from http://www.stonehenge.com/merlyn/UnixReview/col30.html
my %value_for = (
    'ARRAY'  => sub{ return [map { deep_copy($_) } @{$_[0]}]; },
    'HASH'   => sub{ return +{map { $_ => deep_copy($_[0]->{$_}) } keys %{$_[0]}}; },
    'CODE'   => sub{ return $_[0]; },
    'Regexp' => sub{ return $_[0]; },
    '^Idval' => sub{ return $_[0]; },
    );

sub deep_copy {
    my $this = shift;
    if (not ref $this) {
        return $this;
    }
    foreach my $item (keys %value_for)
    {
        if (ref($this) =~ m/$item/)
        {
            my $ret_sub = $value_for{$item};
            return &$ret_sub($this);
        }
    }

    croak  "what type is ", ref $this ,"?";
}

# sub deep_copy {
#     my $this = shift;
#     if (not ref $this) {
#         $this;
#     } elsif (ref $this eq "ARRAY") {
#         [map deep_copy($_), @$this];
#     } elsif (ref $this eq "HASH") {
#         +{map { $_ => deep_copy($this->{$_}) } keys %$this};
#     } elsif (ref $this eq "CODE") {
#         $this;
#     } elsif (ref $this eq "Regexp") {
#         $this;
#     } elsif (ref($this) =~ m{^Idval}) {
#         $this;
#     } else { die "what type is ", ref $this ,"?" }

#     return;
#   }

# Given two references to hash tables, copy assignments from $from to
# $to, without trashing previously-existing assignments in $to (that
# don't exist in $from)
sub deep_assign
{
    my $to = shift;
    my $from = shift;
    my $key;

    foreach my $key (keys %{$from})
    {
        #print STDERR "ref \$from->{$key} is <", ref $from->{$key}, ">\n";
        if (not ref $from->{$key})
        {
            $to->{$key} = $from->{$key};
        }
        elsif (ref $from->{$key} eq "ARRAY")
        {
            $to->{$key} = [@{$from->{$key}}];
        }
        else
        {
            $to->{$key} = {} unless exists($to->{$key});
            deep_assign($to->{$key}, $from->{$key});
        }
    }

    return;
}

sub register_common_object
{
    my $key = shift;
    my $obj = shift;

    $common_objs{$key} = $obj;

    return;
}

sub get_common_object
{
    my $key = shift;

    #print Dumper($common_objs{$key}) if $key eq "help_file";
    croak "Common object \"$key\" not found." unless exists($common_objs{$key});
    return $common_objs{$key};
}

sub get_common_object_hashval
{
    my $key = shift;
    my $subkey = shift;

    return $common_objs{$key}->{$subkey};
}

# So nobody else needs to use Logger;
sub get_logger
{
    # Let others keep me up to date
    $log = Idval::Logger::get_logger();
    return $log;
}

sub make_custom_logger
{
    my $argref = shift;
    $log = Idval::Logger::get_logger();
    return $log->make_custom_logger($argref);
}

sub register_provider
{
    my $argref = shift;

    my $provs = get_common_object('providers');
    $provs->register_provider($argref);
    
    return;
}

sub split_line
{
    my $value = shift;
    my @retlist;

    # This would be a lot prettier if I could figure out how to use Balanced::Text correctly...
    my @fields = extract_multiple($value,
                                  [
                                   sub { extract_delimited($_[0],q{'"})},
                                  ]);

    foreach my $field (@fields)
    {
        $field =~ s/^\s+//x;
        $field =~ s/\s+$//x;
        if ($field =~ m/[''""]/x)
        {
            $field =~ s/^[''""]//x;
            $field =~ s/[''""]$//x;
            push(@retlist, $field);
        }
        else
        {
            push(@retlist, split(' ', $field));
        }
    }

    return \@retlist;
}

sub do_v1tags_only
{
    return 0;
}

sub do_v2tags_only
{
    return 0;
}

sub prefer_v2tags
{
    return 1;
}


# sub safe_get_common_object_hashval
# {
#     my $key = shift;
#     my $subkey = shift;
#     my $default = shift;

#     my $value =  !exists($common_objs{$key})            ? $default
#               :  !exists($common_objs{$key}->{$subkey}) ? $default
#               :  $common_objs{$key}->{$subkey};

#     return $value;
# }


1;
