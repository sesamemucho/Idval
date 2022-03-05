package Idval::Plugins::Command::Update;

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

use Idval::Logger qw(idv_dbg fatal);
use Idval::Common;
use Idval::FileIO;
use Idval::DoDots;
use Idval::Ui;

sub init
{
    return;
}

sub main
{
    my $datastore = shift;
    my $providers = shift;
    my $inputfile = shift;
    my $retval;

    fatal("Need an input file for update\n") unless (defined($inputfile) && $inputfile);

    my $new_datastore = eval {
        Idval::Ui::get_source_from_file($inputfile);};

    fatal("Error: [_1]\n", $@) if $@;
    #idv_dbg("update: datastore: [_1]", Dumper($datastore));
    #idv_dbg("update: new datastore: [_1]", Dumper($new_datastore));

    my $typemap = Idval::Common::get_common_object('typemap');
    my $dotmap = $typemap->get_dot_map();
    Idval::DoDots::init();

    my $tag_record;
    my $type;
    my $prov;
    my %prov_list;
    foreach my $key (sort keys %{$new_datastore->{RECORDS}})
    {
        $tag_record = $new_datastore->{RECORDS}->{$key};
        #idv_dbg("in update with: [_1]", Dumper($tag_record));
        $type = $tag_record->get_value('TYPE');
        $prov = $providers->get_provider('writes_tags', $type, 'NULL');
        $prov_list{$prov} = $prov;

        $retval = $prov->write_tags({tag_record => $tag_record});
        last if $retval != 0;
        Idval::DoDots::dodots($dotmap->{$type});
    }

    map { $_->close() } values %prov_list;
    Idval::DoDots::finish();
    return $new_datastore;
}

=pod

=head1 NAME

X<update>update - Updates files according to a taglist

=head1 SYNOPSIS

update taglist-file

=head1 DESCRIPTION

For each file in F<taglist-file>, B<update> will re-write the tags in
    that file according to the data in taglist-file.

=head1 TODO

B<Update> does not check to see if a file needs to be updated. It
    should probably check against the stored taglist and only update
    the differences.

=cut

1;
