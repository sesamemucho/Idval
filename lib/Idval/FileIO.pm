#
# Provides File IO services, either to the file system, or to a set of
# text arrays (for unit testing).
#
# All file accesses (including -x tests) should go through here.
#
package Idval::FileIO;

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
use IO::File;
use File::Glob;

use Idval::Logger qw(fatal);
use Idval::ServiceLocator;
use Idval::FileSystem;
use Idval::FileString;

our $GLOB_NOCASE = File::Glob::GLOB_NOCASE;
our $GLOB_TILDE  = File::Glob::GLOB_TILDE;

my $implementation;

sub set_imp
{
    my $service_name = shift;
    my $service = shift;

    fatal("Unrecognized service name \"$service_name\" in Idval::FileIO") if $service_name ne "io_type";

    $implementation = $service eq "FileSystem" ? "Idval::FileSystem" :
                      $service eq "FileString" ? "Idval::FileString" :
                      fatal("Unrecognized service \"$service\" for service name io_type");

    return;
}

BEGIN { Idval::ServiceLocator::register_callback('io_type', 'FileIO', 'set_imp', \&set_imp); }

sub AUTOLOAD
{
    use vars qw($AUTOLOAD);

    #print "AUTOLOAD: args: \"", join(" ", @_), "\"\n";
    my $self = shift;

    fatal("File system implementation not set.\n" .
           "Did you forget to call Idval::ServiceLocator::provide('io_type', xxx)?\n") unless $implementation;
    fatal("undefined self") unless defined($self);
    if ($self eq __PACKAGE__)
    {
        unshift @_, $implementation;
    }
    elsif (! ref $self)
    {
        unshift @_, $self;
    }

    elsif (ref $self eq 'CODE')
    {
        unshift @_, $self;
    }

    my $what = $AUTOLOAD;
    (my $val = $what) =~ s/.*:://x;
    #print "AUTOLOADING: \"$what\" using \"$implementation\"\n";
    return if $val =~ m/^[A-Z]*$/x;

    my $sub = "${implementation}::${val}";
    #print "Calling \"$sub\" with \"", join(" ", @_), "\"\n";
    goto &$sub;
}

1;
