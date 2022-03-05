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

use Idval::Logger qw(info_q fatal);
use Idval::Record;
use Idval::FileIO;
use Idval::DoDots;

my $first = 0;

sub init
{
    return;
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

    info_q({force_match => 1}, "Processed [quant,_1,record,records].\n", $numrecs) unless $quiet;

    if ($outputfile)
    {
        $select_coll->source($outputfile);
        my $coll = $select_coll->stringify();

        my $out = Idval::FileIO->new($outputfile, '>') or fatal("Can't open [_1] for writing: [_2]\n", $outputfile, $ERRNO);
        $out->print(join("\n", @{$coll}), "\n");
        $out->close();
    }

    return $select_coll;
}

=pod

=head1 NAME

X<select>select - Selects records from a taglist

=head1 SYNOPSIS

select [options] [selector1 [selector2 [...]]]

 Options:
    --output=<output file>         Prints selected records to F<output file>
    --quiet                        Does not print anything
    --selectfile=<select-config-file>  Uses F<select-config-file>
                                   instead of selectors.

=head1 OPTIONS

=over 4

=item B<--output>=F<output file>

Prints the selected records to F<output file>, I<instead> of to the screen.

=item B<--quiet>

Does not print anything to the screen. B<select> will still modify the
current taglist.

=item B<--selectfile>=F<select-config-file>

Uses selectors from F<select-config-file>, instead of selectors passed
    in as arguments.

=back

=head1 DESCRIPTION

B<select> selects records from the current taglist, and then replaces
    the current taglist with those selected records. It can also print
    the selected records to the screen or file. See
    L<idv/"Configuration files"> for information about selectors.

For B<select>, each selector should be surrounded with quotes. Use
    curly braces "{}" to AND selectors. Selectors with no braces
    around them are ORed together.

=head1 EXAMPLES

  select "TPE1 == Tommy Jarrell" "TYPE == ABC"

will select records where either the artist is Tommy Jarrell or the
    record type is ABC.

  select { "TPE1 == Tommy Jarrell" "TYPE == ABC" }

will select records where the artist is Tommy Jarrell AND the
    record type is ABC.

=cut

1;
