package Idval::Plugins::Command::Gettags;

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
use Getopt::Long;

use Idval::Logger qw(idv_print info_q idv_dbg);
use Idval::Common;
use Idval::FileIO;
use Idval::DoDots;
use Idval::Ui;

my $first = 1;

sub init
{
    return;
}

sub main
{
    my $datastore = shift;
    my $providers = shift;
    my @args = @_;
    my $status;

    my $bypass_mapping = 0;

    local @ARGV = @args;
    my $p = new Getopt::Long::Parser;
    my $result = $p->getoptions('no-mapping' => \$bypass_mapping);
    @args = @ARGV;

    if (!$result or !@args)
    {
        idv_print("Need to specify at least one directory\n") if ($result and !@args);
        my $help_file = Idval::Common::get_common_object('help_file');
        idv_print($help_file->get_full_description('gettags'));
        return $datastore;
    }

    my $typemap = Idval::Common::get_common_object('typemap');
    my $dotmap = $typemap->get_dot_map();
    Idval::DoDots::init();

    info_q("Collecting directory information. Please wait...\n");
    $datastore = Idval::Ui::get_source_from_dirs($providers,
                                                 Idval::Common::get_common_object('config'),
                                                 @args);

    my $tag_record;
    my $type;
    my $prov;
    my %prov_list;

    foreach my $key (sort keys %{$datastore->{RECORDS}})
    {
        idv_dbg("Checking \"[_1]\"\n", $key);
        $tag_record = $datastore->{RECORDS}->{$key};
        $type = $tag_record->get_value('TYPE');
        $prov = $providers->get_provider('reads_tags', $type, 'NULL');
        $prov_list{$prov} = $prov;

        $status = $prov->read_tags({tag_record => $tag_record, bypass_mapping => $bypass_mapping});
        Idval::DoDots::dodots($dotmap->{$type});

        delete $datastore->{RECORDS}->{$key} if $status == 1;
    }

    Idval::DoDots::finish();

    map { $_->close() } values %prov_list;
    return $datastore;
}

=pod

=head1 NAME

gettags - Creates a tag data file from the files in one or more directories.

=head1 SYNOPSIS

gettags [options] directory [directory [...]]

 Options:
   -n|--no-mapping    Don't map tags onto ID3V2 tags (Be careful! You probably don't want to use this!)

=head1 OPTIONS

=over 4

=item B<--no-mapping>

B<Gettags> wants to store tags from music files as ID3v2 tags,
generally speaking. To do this, it maps certain common flags from
other formats, such as ABC, OGG, and FLAC, into corresponding ID3v2
tags when reading tags, and maps them back when writing. The
B<--no-mapping> flag disables this behavior, and lets you see exactly
what tags are in the input files.

This flag should only be used to inspect tags in new files. If you do
use this flag when running B<gettags>, be sure not to B<store> the tag
information afterwards, as B<idval> will not deal with it well. You
can use the B<print> command to view the tag data without saving it.

=back

=head1 DESCRIPTION

X<gettags>

B<Gettags> will go through each given directory and read tag
information from the files it finds there. It places this information
in the current data store. Be sure to use the B<store> command to save
it, otherwise it will be lost at the end of the session.

If the B<gettags> command is given on the B<idv> command line, a
B<store> command is issued automatically (unless a B<--nostore> option
is present).

=head1 EXAMPLES

  gettags /path/to/your/music/files

will get tag information from all files underneath the directory
/path/to/your/music/files.

  gettags /first/tree /second/tree

will get tag information from all files underneath each directory on
the command line. The tag information will be merged.

  gettags "/if/there/are spaces/in the directory name / use  quotes"

  gettags "c:/use forward slashes/on/windows/not backward/slashes"

=cut

1;
