package Idval::Plugins::Command::Select;

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

use Idval::Collection;
use Idval::Constants;
use Idval::Record;
use Idval::FileIO;
use Idval::DoDots;

my $first = 0;

sub init
{
    #set_pod_input();
}

sub main
{
    my $datastore  = shift;
    my $providers  = shift;
    my $outputfile = '';
    my $selectfile = '';
    my $quiet      = 0;
    local @ARGV    = @_;

    my $result = GetOptions('select=s' => \$selectfile,
                            'output=s' => \$outputfile,
                            'quiet'    => \$quiet,
        );

    # We want to add to the config object, but not pollute it for those who follow
    # Storable::dclone doesn't work with regexps
    my $config = Idval::Common::get_common_object('config')->copy();
    my $numrecs = 0;

    # User can either supply a select-file or pass in selectors
    if (@ARGV)
    {
        my $selectors = join("\n", @ARGV);
        $selectors =~ s/([{}])/\n$1\n/g; # Make sure all brackets are alone on their line
        $selectors = "{\n" . $selectors . "\n}\n";
        $config->add_file($selectors);
    }
    elsif ($selectfile)
    {
        # Now, make a new config object that incorporates the select file info.
        $config->add_file($selectfile);
    }

    my $select_coll = Idval::Collection->new();

    foreach my $key (sort keys %{$datastore->{RECORDS}})
    {
        my $tag_record = $datastore->{RECORDS}->{$key};

        if (($first == 0) and ($tag_record->get_value('FILE') =~ m{/home/big/Music/mm/tangier/92407.mp3}))
        {
            print "For record: ", Dumper($tag_record);
            print "config: ", Dumper($config);
            $first = 1;
        }
        if ($first == 1)
        {
            $Idval::Config::DEBUG = 1;
            $config->{DEBUG} = 1;
        }

        my $select_p = $config->selectors_matched($tag_record);
        if ($first > 10)
        {
            $Idval::Config::DEBUG = 0;
            $config->{DEBUG} = 0;
        }
        $first++;

        if ($select_p)
        {
            $select_coll->add($tag_record);
            $numrecs++;
        }
    }

    Idval::Common::get_logger->info_q($DBG_ALL, "Processed $numrecs records.\n") unless $quiet;

    if ($outputfile)
    {
        $select_coll->source($outputfile);
        my $coll = $select_coll->stringify();

        my $out = Idval::FileIO->new($outputfile, '>') or croak "Can't open $outputfile for writing: $ERRNO\n";
        $out->print(join("\n", @{$coll}), "\n");
        $out->close();
    }
    
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
#    $help_file->man_info('select', $pod_input);
# }

1;
