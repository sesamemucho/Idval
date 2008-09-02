package Idval::UserPlugins::Gettags;

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
use English '-no_match_vars';
use Carp;

use Idval::Common;
use Idval::FileIO;
use Idval::DoDots;
use Idval::Ui;

my $first = 1;

sub init
{
    set_pod_input();

    return;
}

sub gettags
{
    my $datastore = shift;
    my $providers = shift;
    my @args = @_;
    my $status;

    #print "Looking at ", join(":", @args), "\n";
    my $typemap = Idval::Common::get_common_object('typemap');
    my $dotmap = $typemap->get_dot_map();
    Idval::DoDots::init();

    $datastore = Idval::Ui::get_source_from_dirs($providers,
                                                 Idval::Common::get_common_object('config'),
                                                 @args);

    my $tag_record;
    my $type;
    my $prov;
    my %prov_list;

    foreach my $key (sort keys %{$datastore->{RECORDS}})
    {
        #print "Checking \"$key\"\n";
        $tag_record = $datastore->{RECORDS}->{$key};
        $type = $tag_record->get_value('TYPE');
        $prov = $providers->get_provider('reads_tags', $type, 'NULL');
        $prov_list{$prov} = $prov;

        $status = $prov->read_tags($tag_record);
        Idval::DoDots::dodots($dotmap->{$type});

        delete $datastore->{RECORDS}->{$key} if $status == 1;
    }

    Idval::DoDots::finish();

    map { $_->close() } values %prov_list;
    #print STDERR Dumper($datastore);
    return $datastore;
}

# sub prolog
# {
#     my $self = shift;
#     my $providers = shift;
#     my $options = shift;
#     my @args = @_;

#     $self->{TYPEMAP} = Idval::TypeMap->new($providers);
#     $self->{PROVIDERS} = $providers;
#     my $typemap = Idval::TypeMap->new($providers);
#     $self->{DOTMAP} = $typemap->get_dot_map();
#     Idval::DoDots::init();

#     $self->set_param('outputfile', exists($options->{'output'}) ? $options->{'output'} : '');

#     $self->{DATA} = Idval::Ui::get_source_from_dirs($providers, $self->{CONFIG}, @args);
#     return $self->{DATA};
# }

# sub each
# {
#     my $self = shift;
#     my $hash = shift;
#     my $key = shift;
#     my $tag_record = $hash->{$key};

#     my $type = $tag_record->get_value('TYPE');
#     my $prov = $self->{PROVIDERS}->get_provider('reads_tags', $type, 'NULL');

#     my $retval = $prov->read_tags($tag_record);
#     Idval::DoDots::dodots($self->{DOTMAP}->{$type});

#     delete $hash->{$key} if $retval == 1;

#     return 0;
# }

# sub epilog
# {
#     my $self = shift;

#     # Let's write out the data as required
#     Idval::Ui::put_source_to_file($self->{DATA}->{RECORDS},
#                                   $self->query('outputfile'),
#                                   $self->{CONFIG}->get_single_value('data_store'));
# }

# sub epilog
# {
#     my $self = shift;
#     my $reclist = shift;

#     print "self: $self, reclist: $reclist\n";
#     # Let's write out the data as required
#     # First, opaquely to the data store
#     my $ds = $self->{CONFIG}->get_single_value('data_store');
#     print "ref reclist: ", ref $reclist, " ds: $ds\n";
#     store($reclist, $ds);
# }

sub set_pod_input
{
    my $help_file = Idval::Common::get_common_object('help_file');

    my $pod_input =<<"EOD";

=head1 NAME

gettags - Creates a tag data file from the files in one or more directories.

=head1 SYNOPSIS

gettags directory [directory [...]]

=head1 OPTIONS

This command has no options.

=head1 DESCRIPTION

X<gettags>

B<Gettags> will go through each given directory and read tag
information from the files it finds there. It places this information
in the current data store. Be sure to use the B<store> command to save
it, otherwise it will be lost at the end of the session.

If the B<gettags> command is given on the B<idv> command line, a
B<store> command is issued automatically (unless a B<--nostore> option
is present).

=cut

EOD
    $help_file->man_info('gettags', $pod_input);

    return;
}

1;
