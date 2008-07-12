package Idval::UserPlugins::Print;

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
use Carp;

use Idval::FileIO;
use Idval::Common;

sub init
{
    set_pod_input();

    return;
}

sub print ## no critic (ProhibitBuiltinHomonyms)
{
    my $datastore = shift;
    my $providers = shift;
    local @ARGV = @_;
    my $outputfile = '-';
    my $full = 0;

    my $result = GetOptions(
        "output=s" => \$outputfile,
        'full' => \$full);

    my $out = Idval::FileIO->new($outputfile, '>') or croak "Can't open $outputfile for writing: $ERRNO\n";

    #print STDERR Dumper($datastore);
    my $coll = $datastore->stringify($full);
    $out->print(join("\n", @{$coll}), "\n");
    $out->close();

    return $datastore;
}

sub set_pod_input
{
    my $help_file = Idval::Common::get_common_object('help_file');

    my $pod_input =<<"EOD";

=head1 NAME

print - Prints a formatted listing of a tag data file.

=head1 SYNOPSIS

print [options] [file]

 Options:
   -outputfile F<output_listing_file> 

=head1 OPTIONS

=over 8

=item B<-outputfile output_listing_file>

If specified, the report will be sent here. Otherwise, the report will be printed to the screen.

=back

=head1 DESCRIPTION

B<Print> print the contents of the given file to the screen. If no
file is given, B<print> will display the contents of the cached
data store.

=cut

EOD
    $help_file->man_info('print', $pod_input);

    return;
}

1;
