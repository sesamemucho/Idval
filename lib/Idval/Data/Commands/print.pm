package Idval::Plugins::Command::Print;

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
use Getopt::Long;
use Data::Dumper;

use Idval::Logger qw(fatal);
use Idval::FileIO;
use Idval::Common;

sub init
{
    return;
}

sub main
{
    my $datastore = shift;
    my $providers = shift;
    local @ARGV = @_;
    my $outputfile = '-';
    my $full = 0;

    my $result = GetOptions(
        "output=s" => \$outputfile,
        'full' => \$full);

    # If there's something left, we've been passed a file handle
    $outputfile = $ARGV[0] if @ARGV;
    my $out = ref $outputfile ? $outputfile :
        Idval::FileIO->new($outputfile, '>') or fatal("Can't open $outputfile for writing: [_1]\n", $ERRNO);

    #print STDERR "print command: ", Dumper($datastore);
    my $coll = $datastore->stringify($full);
    $out->print(join("\n", @{$coll}), "\n");
    $out->close();

    return $datastore;
}

=pod

=head1 NAME

X<print>print - Prints a tagfile.

=head1 SYNOPSIS

print [options] [taglist-file]

 Options:
    --output=<output file>         Prints taglist to F<output file>
    --full                         Prints all tags

=head1 OPTIONS

=over 4

=item B<--outputfile>=F<output file>

Prints a report of the differences found to F<output file>, as well as to the screen.

=item B<--full>

Some tags in a tagfile are created at runtime by B<idv>. These tags
    are not stored when a tagfile is written to disk. If you're
    curious, or debugging, use B<--full>. Otherwise, it will just show
    a lot of irrelevant stuff.

=back

=head1 DESCRIPTION

B<print> prints out a tagfile. This is usually done to edit the file,
    and later update the music files with the B<update> command. If
    there is no F<taglist-file> given, B<print> displays the current
    taglist.

=cut

1;
