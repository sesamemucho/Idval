package Idval::UserPlugins::Update;

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

use Idval::Common;
use Idval::FileIO;
use Idval::DoDots;
use Idval::Ui;

sub init
{
    set_pod_input();

    return;
}

sub update
{
    my $datastore = shift;
    my $providers = shift;
    my $inputfile = shift;
    my $retval;

    croak "Need an input file for update\n" unless (defined($inputfile) && $inputfile);

    my $new_datastore = eval {
        Idval::Ui::get_source_from_file($inputfile);};

    #print "new datastore:", Dumper($new_datastore);
    croak($@) if $@;

    my $typemap = Idval::Common::get_common_object('typemap');
    my $dotmap = $typemap->get_dot_map();
    Idval::DoDots::init();

    my $tag_record;
    my $type;
    my $prov;
    my %prov_list;
    foreach my $key (sort keys %{$new_datastore->{RECORDS}})
    {
        #print "in update with: ", Dumper($tag_record);
        $tag_record = $new_datastore->{RECORDS}->{$key};
        $type = $tag_record->get_value('TYPE');
        $prov = $providers->get_provider('writes_tags', $type, 'NULL');
        $prov_list{$prov} = $prov;

        $retval = $prov->write_tags($tag_record);
        last if $retval != 0;
        Idval::DoDots::dodots($dotmap->{$type});
    }

    map { $_->close() } values %prov_list;
    Idval::DoDots::finish();
    return $new_datastore;
}

sub set_pod_input
{
    my $help_file = Idval::Common::get_common_object('help_file');

    my $pod_input =<<"EOD";

=head1 NAME

update - updates tag information according to a tag data file

=head1 SYNOPSIS

update file

=head1 OPTIONS

This command has no options.

=head1 DESCRIPTION

B<Update> will cause the files referenced in the tag data file B<file>
to have the tag data indicated by B<file>. This command is what you
use to change tag information in your files.

=cut

EOD
    $help_file->man_info('update', $pod_input);

    return;
}

1;
