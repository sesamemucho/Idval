package Idval::Record;

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

use Idval::Ui;

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
    my $arg = shift;

    if (ref $arg eq "Idval::Record")
    {
        $self->set_name($arg->get_name());
        foreach my $tag ($arg->get_all_keys())
        {
            $self->add_tag($tag, $arg->get_value($tag));
        }
    }
    else
    {
        $self->set_name($arg);
    }
}

# Return a subset of the tag/values so that
# Idval::Config::_merge_blocks (which is memoized)
# can work effectively.
#
# Bah! Everything! (almost)
sub get_selectors
{
    my $self = shift;
    my %sels;

    foreach my $tag (keys %{$self})
    {
        next if $tag eq '__LINE';
        next if $tag eq '__NEXT_LINE';

        $sels{$tag} = $self->{$tag};
    }

#     $sels{CLASS} = $self->{CLASS} if exists $self->{CLASS};
#     $sels{TYPE} = $self->{TYPE} if exists $self->{TYPE};
#     $sels{FILE} = $self->{FILE} if exists $self->{FILE};
#     # Add more as desired
#     #$sels{} = $self->{} if exists $self->{};
#     #$sels{} = $self->{} if exists $self->{};
#     #$sels{} = $self->{} if exists $self->{};

    return \%sels;
}

sub add_tag
{
    my $self = shift;
    my $name = shift;
    my $value = shift;

    $self->{$name} = $value;
}

# Add a line of text to an already-existing tag.
# Make sure the added line is indented (for later parsing),
# and is not blank.
sub add_to_tag
{
    my $self = shift;
    my $name = shift;
    my $value = shift;

    $value =~ s/[\n\r]//g;
    return if $value =~ m/^\s*$/;
    $value =~ s/^\s*/    /;
    $self->{$name} .= "\n$value";
}

sub get_value
{
    my $self = shift;
    my $tagname = shift;

    return $self->{$tagname};
}

sub get_name
{
    my $self = shift;

    return $self->{FILE};
}

sub set_name
{
    my $self = shift;
    my $name = shift;

    $self->{FILE} = $name;
}

# Actually, "get all keys, except for those that are calculated"
sub get_all_keys
{
    my $self = shift;
    return grep(!/^(:?FILE|CLASS|TYPE|__LINES|__NEXT_LINE)$/, sort keys %{$self});
}

sub key_exists
{
    my $self = shift;
    my $key = shift;

    return exists($self->{$key});
}

sub get_value_as_arg
{
    my $self = shift;
    my $flag = shift;
    my $key = shift;

    my $retval = '';
    #print STDERR "Checking for key \"$key\": ", $self->key_exists($key) ? "yep" : 'nope', "\n";
    if($self->key_exists($key))
    {
        $retval = $flag . "\"" . $self->get_value($key) . "\"";
    }

    return $retval;
}

sub format_record
{
    my $self = shift;
    my $start_line = shift; # = undef if not present

    my @output = ('FILE = ' . $self->get_name());
    my %lines;

    $lines{'FILE'} = $start_line++ if defined $start_line;

    foreach my $tag (sort keys %{$self})
    {
        next if $tag eq 'FILE';
        next if $tag eq 'CLASS';
        next if $tag eq 'TYPE';
        next if $tag eq '__LINES';
        next if $tag eq '__NEXT_LINE';

        push(@output, "$tag = " . $self->get_value($tag));
        $lines{$tag} = $start_line++ if defined $start_line;
    }

    push(@output, ''); # This is needed to get one blank line separating the file records,
    # which is used later on to parse them.

    if (defined $start_line)
    {
        $self->{__LINES} = \%lines;
        $self->{__NEXT_LINE} = $start_line + 1;
    }

    return @output;
}

sub diff
{
    my $self = shift;
    my $other = shift;
    my $this_val;
    my $other_val;
    my %common_diffs = ();

    my ($self_not_other, $self_and_other, $other_not_self) = 
        Idval::Ui::get_rec_diffs($self, $other);

    foreach my $tag (sort keys %{$self_and_other})
    {
        $this_val = $self->get_value($tag);
        $other_val = $other->get_value($tag);
        if ($this_val ne $other_val)
        {
            $common_diffs{$tag} = [$this_val, $other_val];
        }
    }

    if (!wantarray())
    {
        return (%{$self_not_other} or %{$other_not_self} or %common_diffs);
    }
    else
    {
        return ($self_not_other, \%common_diffs, $other_not_self);
    }
}

1;
