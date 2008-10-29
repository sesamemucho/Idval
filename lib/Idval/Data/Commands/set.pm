package Idval::Plugins::Command::Set;

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

use Getopt::Long;
use Pod::Usage;
use Data::Dumper;
use English '-no_match_vars';;
use Carp;

use Idval::Constants;
use Idval::Logger;

my $first = 0;

sub init
{
    set_pod_input();
}

sub main
{
    my $datastore  = shift;
    my $providers  = shift;

    local @ARGV    = @_;

#     my $result = GetOptions('select=s' => \$selectfile,
#                             'output=s' => \$outputfile,
#                             'quiet'    => \$quiet,
#         );

    return $datastore unless @ARGV;

    my $args = join(' ', @ARGV);

    if ($args =~ m/^(\S+)(?:\s+(\S+))?/)
    {
        my $param = lc $1;
        my $value = $2;
        my $newvalue;

        if ($param eq 'debug')
        {
            $newvalue = Idval::Common::get_logger()->accessor('DEBUGMASK', $2);
        }
        elsif ($param eq 'level')
        {
            $newvalue = Idval::Common::get_logger()->accessor('LOGLEVEL', $2);
        }
        else
        {
            print "Unrecognized \"set\" parameter: \"$param\" (try \"help set\")\n";
            return $datastore;
        }

        print "Value for \"$param\" is $newvalue\n";
    }
    else
    {
        print "Unrecognized \"set\" command: \"$args\" (try \"help set\")\n";
    }

    return $datastore;
}

sub set_pod_input
{
    my $help_file = Idval::Common::get_common_object('help_file');

    my $pod_input =<<EOD;

=head1 NAME

set - Sets various run-time parameters (for debugging)

=head1 SYNOPSIS

set <param> = <value>

=head1 OPTIONS

This command has no options.

=head1 DESCRIPTION

B<Set> will ...

=cut

EOD
   $help_file->man_info('set', $pod_input);
}

1;
