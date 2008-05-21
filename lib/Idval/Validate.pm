package Idval::Validate;

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
use Idval::Constants;
use Idval::Data::Genres;

use base qw( Idval::Config );

my $perror = '';

# Is this a valid function name for the 'passes' validation operand?
sub CheckFunction
{
    my $func = shift;

    return 1 if $func =~ m/^(Check_Genre_for_id3v1)$/;

    $perror = "Unknown validation function \"$func\"";
}

sub perror
{
    my $retval = $perror;

    $perror = '';

    return $retval;
}

sub Check_Genre_for_id3v1
{
    my $tagvalue = lc(shift);

    return exists($Idval::Data::Genres::name2id{$tagvalue});
}

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    bless($self, ref($class) || $class);
    *verbose = Idval::Common::make_custom_logger({level => $VERBOSE, 
                                                  debugmask => $DBG_CONFIG,
                                                  decorate => 1}) unless defined(*verbose{CODE});
    *chatty  = Idval::Common::make_custom_logger({level => $CHATTY,
                                                  debugmask => $DBG_CONFIG,
                                                  decorate => 1}) unless defined(*chatty{CODE});

    return $self;
}

sub get_blocks
{
    my $self = shift;
    my $selects = shift;
    my %vars;

    verbose("Start of _merge_blocks, selects: ", Dumper($selects));

    # visit each node, in correct order
    # if node evaluates to TRUE,
    #  Accumulate it
    # When finished with tree, return list of selected blocks

    my $visitor = sub {
        my $node = shift;

        return undef if $node->evaluate($selects) == 0;

        if (exists $node->{ASSIGNMENT_DATA})
        {
            $vars{$node->myname()} = $node;
        }
    };

    $self->visit($self->{TREE}, $visitor);

    chatty("Result of merge blocks - VARS: ", Dumper(\%vars));

    return \%vars;
}

1;
