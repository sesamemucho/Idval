package Idval::Plugins::Command::Read;

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

use Idval::Logger qw(verbose);
use Idval::Common;
use Idval::Ui;

sub init
{
    return;
}

sub main
{
    my $datastore = shift;
    my $providers = shift;
    my $inputfile =  shift || '';
    my $config = Idval::Common::get_common_object('config');

    #print "read.pm: inputfile is: \"$inputfile\"\n";
    my $loc = $inputfile ? $inputfile : 'Cached data store';
    verbose("Reading tag information from \"[_1]\"\n", $loc);

    if ($inputfile)
    {
        $datastore = Idval::Ui::get_source_from_file($inputfile);
    }
    else
    {
        my $dsfile = $config->i18n_get_single_value('config', 'data_store', {'config_group' => 'idval_settings'});
        $datastore = eval {Idval::Ui::get_source_from_cache("${dsfile}.bin", "${dsfile}.dat");};
    }

    Idval::Common::register_common_object('data', $datastore);

    return $datastore;
}

=pod

=head1 NAME

X<read>read - Reads a taglist file into the current taglist

=head1 SYNOPSIS

read [taglist-file]

=head1 DESCRIPTION

B<read> reads the contents of F<taglist-file> into the current
    taglist. If no taglist-file is specified, then B<read> reads the
    contents of the stored file into the current taglist.

B<idv> will automatically issue a B<read> command when it starts, to
    load the stored taglist file into the current taglist.

=cut

1;
