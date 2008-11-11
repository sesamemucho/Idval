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

use Idval::Logger qw(:vars idv_print);

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

    my $param = shift @ARGV;

    if (!defined($param) or !$param)
    {
        idv_print("set commands are:\n", join("    \n", qw(conf debug level)), "\n");
    }
    elsif ($param eq 'debug')
    {
        my $modhash = Idval::Common::get_logger()->set_debugmask(join(' ', @ARGV));
#         my @info = sort { $modhash->{$a}->{STR} cmp $modhash->{$b}->{STR} } keys %{$modhash};
        my @info = map  { $_->[0] }
                   sort { $a->[1] cmp $b->[1] }
                   map  { [$_, $modhash->{$_}->{STR} ] }
                   keys %{$modhash};

        idv_print("  Module spec       level\n");
        foreach my $item (@info)
        {
            idv_print(sprintf("%-20s  %d\n", $modhash->{$item}->{STR}, $modhash->{$item}->{LEVEL}));
        }
        #idv_print("Debug mask is: ", join(' ', @newmods), "\n");
    }
    elsif ($param eq 'level')
    {
        my $helpsub = sub {
            idv_print("Available debug levels are:\n");
            foreach my $level (sort {$a <=> $b} keys %level_to_name)
            {
                idv_print(sprintf("    %8s: %d\n", $level_to_name{$level}, $level));
            }

            my $current_level = Idval::Common::get_logger()->accessor('LOGLEVEL');
            idv_print("\nCurrent level is: $current_level (", $level_to_name{$current_level}, ")\n");
        };

        if (@ARGV)
        {
            my $newlevel = shift @ARGV;
            if (exists($level_to_name{$newlevel}))
            {
                Idval::Common::get_logger()->accessor('LOGLEVEL', $newlevel);
                my $current_level = Idval::Common::get_logger()->accessor('LOGLEVEL');
                idv_print("\nNew level is: $current_level (", $level_to_name{$current_level}, ")\n");
            }
            elsif (exists($name_to_level{lc($newlevel)}))
            {
                Idval::Common::get_logger()->accessor('LOGLEVEL', $name_to_level{lc($newlevel)});
                my $current_level = Idval::Common::get_logger()->accessor('LOGLEVEL');
                idv_print("\nNew level is: $current_level (", $level_to_name{$current_level}, ")\n");
            }
            else
            {
                idv_print("Unrecognized level \"$newlevel\"\n");
                &$helpsub();
            }
        }
        else
        {
            &$helpsub();
        }
    }
    elsif ($param eq 'conf')
    {
        require Idval::FirstTime;
        my $config = Idval::Common::get_common_object('config');
        my $cfgfile = Idval::FirstTime::init($config);
        print "conf: got \"$cfgfile\"\n";
        #$config->add_file($cfgfile);
    }
    else
    {
        idv_print("Unrecognized \"set\" command: \"", join(' ', @ARGV), "\" (try \"help set\")\n");
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
