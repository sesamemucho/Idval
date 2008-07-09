package Idval::UserPlugins::Read;

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

use English '-no_match_vars';
use Data::Dumper;
use Carp;

use Idval::Constants;
use Idval::Common;
use Idval::Ui;

sub init
{
    *mylog = Idval::Common::make_custom_logger({level => $VERBOSE,
                                               debugmask => $DBG_PROCESS,
                                               decorate => 1});

    set_pod_input();

    return;
}

sub read ## no critic (ProhibitBuiltinHomonyms)
{
    my $datastore = shift;
    my $providers = shift;
    my $inputfile =  shift || '';
    my $config = Idval::Common::get_common_object('config');

    #print "read.pm: inputfile is: \"$inputfile\"\n";
    my $loc = $inputfile ? $inputfile : 'Cached data store';
    mylog("Reading tag information from \"$loc\"\n");
    $datastore = eval {
        Idval::Ui::get_source_from_file($inputfile, $config->get_single_value('data_store',
                                                                              {'config_group' => 'idval_settings'}));};

    print "Got back from eval, ret is \"$@\"\n";
    if ($@)
    {
        $@ =~ s/\r//g;
        croak("Got error from Idval::Ui::get_source_from_file: ", $@, "\n") if $@;
    }

    Idval::Common::register_common_object('data', $datastore);

    return $datastore;
}

sub set_pod_input
{
    my $help_file = Idval::Common::get_common_object('help_file');

    my $pod_input =<<"EOD";

=head1 NAME

read_data - Reads a tag data file into the current data store.

=head1 SYNOPSIS

read_data [file]

=head1 OPTIONS

This command has no options.

=head1 DESCRIPTION

B<Read_Data> will read the given tag data file and place it into the
current data store, where it can be used by other programs. Either
B<read_data> or B<gettags> must be run in order to bring data into the
system so that other commands can use it.

If a command is given on the B<idv> command line, a B<read_data> command is
executed automatically before the given command.

If no file is given to B<read_data>, the cached data store is read into the
current data store.

=cut

EOD
    $help_file->{'read_data'} = $pod_input;

    return;
}

1;
