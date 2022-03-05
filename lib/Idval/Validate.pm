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

use Idval::Common;
use Idval::Logger qw(idv_dbg);
use Idval::Data::Genres;

use base qw( Idval::Config );

my $perror = '';

# Is this a valid function name for the 'passes' validation operand?
sub CheckFunction
{
    my $func = shift;

    return 1 if $func =~ m/^(Check_Genre_for_id3v1)$/;

    $perror = "Unknown validation function \"$func\"";

    return;
}

sub perror
{
    my $retval = $perror;

    $perror = '';

    return $retval;
}

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    bless($self, ref($class) || $class);
    $self->{ALLOW_KEY_REGEXPS} = 1;
    return $self;
}

sub parse_vars
{
    my $self = shift;
    my @vars = @_;
    my @results = ();

    #print STDERR ("Validate: In parse_vars, got ", scalar(@vars), "\n");
    idv_dbg("In parse_vars, got [quant,_1,var,vars]\n", scalar(@vars));
    foreach my $varinfo (@vars)
    {
        my ($var, $op, $value) = @{$varinfo};
        next unless $var eq 'GRIPE';

        #push(@results, 'print STDERR "keys of ar_selects: ", join(",", keys(%{$ar_selects})), "\n";');
        #push(@results, 'print STDERR "matching regexp tags: ", join(",", @{$rg_matched_tags}), "\n";');
        push(@results, '$vars{q{' . $value . '}} = [keys(%{$ar_selects}), @{$rg_matched_tags}];');
    }

    return @results;
}

package Idval::ValidateFuncs;

use strict;
use Data::Dumper;
use Scalar::Util;

#use Idval::Logger(fatal);

sub Check_Genre_for_id3v1
{
    my $selectors = shift;
    my $tagname = shift;
    my $tagvalue = lc($selectors->{$tagname});

    return Idval::Data::Genres::isNameValid($tagvalue);
}

sub Check_For_Existance
{
    #print "Args are: ", Dumper(@_);
    #confess "Bye";
    my $selectors = shift;
    my $tagname = shift;
    my $retval = exists $selectors->{$tagname};
    return $retval;
}

sub Is_A_Number
{
    #print "Args are: ", Dumper(@_);
    #confess "Bye";
    my $selectors = shift;
    my $tagname = shift;
    my $tagvalue = lc($selectors->{$tagname});

    my $retval = Scalar::Util::looks_like_number($tagvalue);
    return $retval;
}

1;
