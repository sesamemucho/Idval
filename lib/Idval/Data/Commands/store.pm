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
    set_pod_input();

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

    fatal("Bad \"datastore\" (ref is \"", ref $datastore , "\"\n") unless ref $datastore eq 'Idval::Collection';
    fatal("Bad \"providers\" (ref is \"", ref $providers , "\"\n") unless ref $providers eq 'Idval::ProviderMgr';

    # Let's write out the data as required
    Idval::Ui::put_source_to_file({datastore => $datastore,
                                   outputfile => $outputfile,
                                   datastore_file => $config->get_single_value('data_store', {'config_group' => 'idval_settings'}),
                                  });

    return $datastore;
}

sub set_pod_input
{
    my $help_file = Idval::Common::get_common_object('help_file');

    my $pod_input =<<"EOD";

=head1 NAME

store - Saves the current data store.

=head1 SYNOPSIS

store [options] [file]

 Options:
   -nocache

=head1 OPTIONS

=over 8

=item B<-nocache>

If specified, B<store> will not save the current data store in the cache file.

=back

=head1 DESCRIPTION

B<Store> will write the current data store to the cached data
store. If a B<file> argument is present, B<store> will write the data
store into that file instead.

Note: any changes to the data store made during a session will be lost
unless a B<store> command is issued!

=cut

EOD
    $help_file->man_info('store', $pod_input);

    return;
}

1;
