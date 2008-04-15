package Idval::UserPlugins::Select;

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

use Getopt::Long;
use Pod::Usage;
use Data::Dumper;
use English;
use Carp;

use Idval::Collection;
use Idval::Record;
use Idval::FileIO;
use Idval::DoDots;

our $first = 0;

sub init
{
    #set_pod_input();
}

sub select
{
    my $datastore = shift;
    my $providers = shift;
    my $outputfile = '-';
    local @ARGV = @_;
    my $result = GetOptions("output=s" => \$outputfile);

    my $out = Idval::FileIO->new($outputfile, '>') or croak "Can't open $outputfile for writing: $ERRNO\n";

    # We want to add to the config object, but not pollute it for those who follow
    # Storable::dclone doesn't work with regexps
    my $config = Idval::Common::deep_copy(Idval::Common::get_common_object('config'));

    my $selectfile = defined($ARGV[0]) ? $ARGV[0] : '';
    croak "Need a select file." unless $selectfile;
    # Now, make a new config object that incorporates the select file info.
    $config->add_file($selectfile);
    my $select_coll = Idval::Collection->new();

    foreach my $key (sort keys %{$datastore->{RECORDS}})
    {
        my $record = $datastore->{RECORDS}->{$key};
        my $select_p = $config->get_single_value('select', $record);
        if (($first == 0) and ($record->get_value('ARTIST') eq 'John Hartford & Friends'))
        {
            print "For record: ", Dumper($record);
            print "config: ", Dumper($config);
            $first = 1;
        }
        $select_coll->add($record) if $select_p;
    }

    my $coll = $select_coll->stringify();
    $out->print(join("\n", @{$coll}), "\n");
    $out->close();
    
    return $select_coll;
}

# sub set_pod_input
# {
#     my $help_file = Idval::Common::get_common_object('help_file');

#     my $pod_input =<<EOD;

# =head1 NAME

# select - selects tag information according to a tag data file

# =head1 SYNOPSIS

# select file

# =head1 OPTIONS

# This command has no options.

# =head1 DESCRIPTION

# B<Select> will cause the files referenced in the tag data file B<file>
# to have the tag data indicated by B<file>. This command is what you
# use to change tag information in your files.

# =cut

# EOD
#     $help_file->{'select'} = $pod_input;
# }

1;
