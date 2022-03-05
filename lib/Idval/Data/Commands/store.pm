package Idval::Plugins::Command::Store;

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
use Getopt::Long;
use English '-no_match_vars';;

use Idval::Logger qw(fatal);
use Idval::FileIO;
use Idval::DoDots;
use Idval::Ui;

sub init
{
    return;
}

sub main
{
    local @ARGV = @_;

    my $config = Idval::Common::get_common_object('config');
    my $usecache = 1;

    my $opts = Getopt::Long::Parser->new();
    my $retval = $opts->getoptions('cache!' => \$usecache);

    my $datastore = shift;
    my $providers = shift;
    my $outputfile = shift || '';

    fatal("Bad \"datastore\" (ref is \"[_1]\"\n", ref $datastore) unless ref $datastore eq 'Idval::Collection';
    fatal("Bad \"providers\" (ref is \"[_1]\"\n", ref $providers) unless ref $providers eq 'Idval::ProviderMgr';

    # Let's write out the data as required
    Idval::Ui::put_source_to_file({datastore => $datastore,
                                   outputfile => $outputfile,
                                   datastore_file => $config->i18n_get_single_value('config', 'data_store', {'config_group' => 'idval_settings'}),
                                  });

    return $datastore;
}

=pod

=head1 NAME

X<store>store - Stores the current taglist into the data store.

=head1 SYNOPSIS

store [tagfile-name]

=head1 DESCRIPTION

B<store> writes the current taglist into the stored taglist cache
    file. This is very important to do after a B<gettags> command,
    since otherwise the new data may be lost. If there is a
    F<tagfile-name>, then the data is I<also> written to
    F<tagfile-name>.

=cut

1;
