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

use Idval::I18N;
use Idval::Logger qw(:vars idv_print);

my $first = 0;
my %cmds;

sub init
{
    my $lh = Idval::I18N->get_handle() || die "Can't get a language handle!";
    foreach my $cmd_id (qw(conf debug))
    {
        my $cmd_str = $lh->maketext("set_cmd=" . $cmd_id) || die "No command found for set command \"$cmd_id\"\n";
        $cmd_str =~ s/^set_cmd=//;
        $cmds{$cmd_id} = $cmd_str;
    }
}

sub main
{
    my $datastore  = shift;
    my $providers  = shift;

    local @ARGV    = @_;

    my $param = shift @ARGV;

    if (!defined($param) or !$param)
    {
        idv_print("set commands are: conf and debug\n");
    }
    elsif ($param eq $cmds{'debug'})
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
            idv_print("[sprintf,%-20s  %d,_1,_2]\n", $modhash->{$item}->{STR}, $modhash->{$item}->{LEVEL});
        }
    }
    elsif ($param eq $cmds{'conf'})
    {
        require Idval::FirstTime;
        my $config = Idval::Common::get_common_object('config');
        my $ft = Idval::FirstTime->new($config);
        my $cfgfile = $ft->setup();
        print "conf: got \"$cfgfile\"\n";
        #$config->add_file($cfgfile);
    }
    else
    {
        idv_print("Unrecognized \"set\" command: \"[_1]\" (try \"help set\")\n", join(' ', @ARGV));
    }

    return $datastore;
}

=pod

=head1 NAME

X<set>set - Sets configuration values

=head1 SYNOPSIS

set debug|conf

=head1 DESCRIPTION

B<set> sets certain configuration values. Currently, the only two set
    commands available are

=over 4

=item debug

Sets debug levels for modules as described in L<Logger>.

=item conf

Re-runs the startup configuration utility, just as though this were the
    first run of B<idv>.

=back

=cut

1;
