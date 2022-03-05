#
# A simple-minded way to do dependency injection.
#
package Idval::ServiceLocator;

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

use Idval::Logger qw(verbose fatal);
use Idval::Common;

my %services;
my %callbacks;
my %registered_callbacks;

sub provide
{
    my $service_name = shift;
    my $service = shift;

    $services{$service_name} = $service;
    if (exists($callbacks{$service_name}))
    {
        foreach my $cb_item (@{$callbacks{$service_name}})
        {
            my ($cb_name, $cb) = @{$cb_item};
            #print STDERR "Calling a callback \$cb_name\" with service name \"$service_name\"\n";
            &$cb($service_name, $service);
        }
    }

    return;
}

#
# Register a routine to be called when <service_name> is set.
# This routine should take two arguments, service_name and service.
#
sub register_callback
{
    my $service_name = shift;
    my $callback_name = shift;
    my $callback_routine_name = shift;
    my $cb = shift;

    if (!exists($registered_callbacks{"$service_name/$callback_name/$callback_routine_name"}))
    {
        verbose("Registering callback with \"[_1]\"\n", "$service_name/$callback_name/$callback_routine_name");
        push(@{$callbacks{$service_name}}, [$callback_name, $cb]);
        $registered_callbacks{"$service_name/$callback_name/$callback_routine_name"} = 1;
    }

    return;
}

sub locate
{
    my $service_name = shift;

    if (!exists($services{$service_name}))
    {
        fatal("Unregistered service \"[_1]\" requested.\n", $service_name);
    }

    return $services{$service_name};
}

1;
