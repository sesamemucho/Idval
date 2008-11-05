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

use Pod::Usage;
use Pod::Select;

my $help_info;


sub new
{
    my $class = shift;
    my $self = {};
    bless($self, ref($class) || $class);
    $self->_init(@_);
    return $self;
}

sub _init
{
    my $self = shift;
}

sub man_info
{
    my $self = shift;
    my $src = shift;
    my $info = shift;

    $help_info->{MAN}->{$src} = $info if defined($info);
    return $help_info->{MAN}->{$src};
}

sub detailed_info_ref
{
    my $self = shift;
    my $src = shift;
    my $pkg = shift;
    my $info = shift;

    $help_info->{DETAIL}->{$src}->{$pkg} = $info if defined($pkg);

    return $help_info->{DETAIL}->{$src};
}

sub _call_pod2usage
{
    my $self = shift;
    my $name = shift;
    my @sections = @_;

    my $usage = '';
    my $temp_store = '';

    my $input = $self->man_info($name);
    return "$name: no information available" unless defined($input);

    open(my $INPUT, '<', \$input) || die "Can't open in-core filehandle for pod_input: $!\n";
    open(my $TEMP, '>', \$temp_store) || die "Can't open in-core filehandle for temp_store: $!\n";
    my $selector = new Pod::Select();
    $selector->select(@sections);
    $selector->parse_from_file($INPUT, $TEMP);
    close $TEMP;
    close $INPUT;

    open($INPUT, '<', \$temp_store) || die "Can't open in-core filehandle for reading temp_store: $!\n";
    open(my $FILE, '>', \$usage) || die "Can't open in-core filehandle: $!\n";
    my $parser = new Pod::Text();
    $parser->parse_from_filehandle($INPUT, $FILE);
    close $FILE;
    close $INPUT;

    return $usage;
}

sub get_short_description
{
    my $self = shift;
    my $name = shift;
    my $usage = $self->_call_pod2usage($name, "NAME");

    # Now trim it
    $usage =~ s/Name\s*//si;
    $usage =~ s/\n\n*/\n/gs;
    $usage =~ s/\n*$//;
    return $usage;
}

sub get_full_description
{
    my $self = shift;
    my $name = shift;

    my $usage = $self->_call_pod2usage($name, '');

    return $usage;
}

sub get_synopsis
{
    my $self = shift;
    my $name = shift;

    my $usage = $self->_call_pod2usage($name, 'SYNOPSIS', 'OPTIONS');

    return $usage;
}

1;
