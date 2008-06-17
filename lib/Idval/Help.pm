package Idval::Help;

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

use Carp;
use Pod::Usage;
use Pod::Select;

sub _call_pod2usage
{
    my $name = shift;
    my @sections = @_;

    my $usage = '';

    my $help_file = Idval::Common::get_common_object('help_file');

    return "$name: no information available" unless exists $help_file->{$name};

    my $input = $help_file->{$name};
    open(my $INPUT, '<', \$input) || die "Can't open in-core filehandle for pod_input: $!\n";
    open(my $FILE, '>', \$usage) || die "Can't open in-core filehandle: $!\n";
    my $parser = new Pod::Text();
    $parser->select(@sections);
    $parser->parse_from_filehandle($INPUT, $FILE);
    close $FILE;
    close $INPUT;

    return $usage;
}

sub get_short_description
{
    my $name = shift;
    my $usage = _call_pod2usage($name, "NAME");

    # Now trim it
    $usage =~ s/Name\s*//si;
    $usage =~ s/\n\n*/\n/gs;
    $usage =~ s/\n*$//;
    return $usage;
}

sub get_full_description
{
    my $name = shift;

    my $usage = _call_pod2usage($name, '');

    return $usage;
}

sub get_synopsis
{
    my $name = shift;

    my $usage = _call_pod2usage($name, 'SYNOPSIS', 'OPTIONS');

    return $usage;
}

1;
