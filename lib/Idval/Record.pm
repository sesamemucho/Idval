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
use Idval::Data::Genres;

# Calculated tags start with '__'. There are three exceptions:
# FILE, TYPE, and CLASS.
my $strict_calc_tag_re = qr/^__\S+$/o;
my $calculated_tags_re = qr/^(:?FILE|CLASS|TYPE|__\S+)$/o;

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
    my $argref = shift;

    if (exists($argref->{Record}))
    {
        my $rec = $argref->{Record};
        my $tag_value;

        $self->add_tag('FILE', $rec->get_name());
        foreach my $tagname ($rec->get_all_keys())
        {
            $tag_value = $rec->get_value($tagname);
            if (ref $tag_value eq 'ARRAY')
            {
                # Make a copy so shift_value() will work correctly
                $self->add_tag($tagname, [(@{$tag_value})]);
            }
            else
            {
                $self->add_tag($tagname, $tag_value);
            }
        }

        delete $argref->{Record};
    }
    else
    {
        confess "A new Record must have a filename." if !exists($argref->{FILE});
    }

    foreach my $tagname (keys %{$argref})
    {
        #print STDERR "Record: Adding \"$tagname\" to new record.\n";
        $self->add_tag($tagname, $argref->{$tagname});
    }

    return;
}

# Return a subset of the tag/values so that
# Idval::Config::_merge_blocks (which is memoized)
# can work effectively.
#
# Bah! Everything! (almost)
sub get_selectors
{
    my $self = shift;
    my $sels;

    foreach my $tag (keys %{$self})
    {
        next if $tag =~ $calculated_tags_re;
        $sels->{$tag} = $self->{$tag};
    }

#     $sels{CLASS} = $self->{CLASS} if exists $self->{CLASS};
#     $sels{TYPE} = $self->{TYPE} if exists $self->{TYPE};
#     $sels{FILE} = $self->{FILE} if exists $self->{FILE};
#     # Add more as desired
#     #$sels{} = $self->{} if exists $self->{};
#     #$sels{} = $self->{} if exists $self->{};
#     #$sels{} = $self->{} if exists $self->{};

    return $sels;
}

sub add_tag
{
    my $self = shift;
    my $name = shift;
    my $value = shift;

    confess "undefined tag name" unless defined($name);

    #$self->{TEMP}->{$name} = $value;
    if (ref $value eq 'ARRAY')
    {
        foreach my $item (@$value)
        {
            # Remove blank lines (for parsing)
            $item =~ s/(\r\n|\n|\r)\s*(?:\r\n|\n|\r)*/$1/g;
            # indent for later parsing
            $item =~ s/([\r\n]+)(?!$)/$1  /g;
        }
    }

    $self->{$name} = defined($value) ? $value : '';

    return;
}

# Add a line of text to an already-existing tag.
# Make sure the added line is indented (for later parsing),
# and is not blank.
sub add_to_tag
{
    my $self = shift;
    my $name = shift;
    my $value = shift;

    $value =~ s/[\n\r]//gx;
    return if $value =~ m/^\s*$/x;
    $value =~ s/^\s*/\ \ \ \ /x;
    #$self->{TEMP}->{$name} .= "\n$value";
    $self->{$name} .= "\n$value";

    return;
}

sub get_value
{
    my $self = shift;
    my $tagname = shift;

    return $self->{$tagname};
}

# Return a string representing the tag value, whatever type it is
# Sort of like a baby Data::Dumper
sub get_flattened_value
{
    my $self = shift;
    my $tagname = shift;
    my $value = $self->get_value($tagname);
    my $retval = $value;

    if (ref $value eq 'ARRAY')
    {
        $retval = '[' . join(', ', @{$value}) . ']';
    }

    return $retval;
}

sub get_first_value
{
    my $self = shift;
    my $tagname = shift;

    my $retval = '';

    if ($self->key_exists($tagname))
    {
        if (ref $self->{$tagname} eq 'ARRAY')
        {
            $retval = ${$self->{$tagname}}[0];
        }
        else
        {
            $retval = $self->{$tagname};
        }
    }

    return $retval;
}

sub get_name
{
    my $self = shift;

    return $self->{FILE};
}

# Returns a tag value and deletes it from the record.
# This routine, I would think, should only be used on a copy of a Record
sub shift_value
{
    my $self = shift;
    my $tagname = shift;
    my $retval = '';

    if ($self->key_exists($tagname))
    {
        if (ref $self->{$tagname} eq 'ARRAY')
        {
            $retval = shift @{$self->{$tagname}};
            #print "\nFor $tagname, returning \"$retval\" Remaining: ", join(':', @{$self->{$tagname}}), "\n";
            delete $self->{$tagname} if scalar @{$self->{$tagname}} == 0;
        }
        else
        {
            $retval = $self->{$tagname};
            delete $self->{$tagname};
        }
    }

    return $retval;
}

sub set_name
{
    my $self = shift;
    my $name = shift;

    $self->{FILE} = $name;

    return;
}

sub get_calculated_keys_re
{
    my $self = shift;
    return $calculated_tags_re;
}

# Actually, "get all keys, except for those that are calculated"
sub get_all_keys
{
    my $self = shift;
    my @retval = grep {!/$calculated_tags_re/} sort keys %{$self};
    #print STDERR "Record: From (", join(',', sort keys %{$self}), "), returning (", join(',', @retval), ")\n";
    return @retval;
}

# refactoring...
sub get_diff_keys
{
    my $self = shift;

    return $self->get_all_keys();
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
    #print STDERR "Record: Checking for key \"$key\": ", $self->key_exists($key) ? "yep" : 'nope', "\n";
    if($self->key_exists($key))
    {
        $retval = $flag . "\"" . $self->get_value($key) . "\"";
    }

    return $retval;
}

sub format_record
{
    my $self = shift;
    my $argref = shift;

    confess "Record::format_record: bogus arg_ref\n" if $argref and (ref $argref ne 'HASH');

    my $start_line = exists $argref->{start_line} ? $argref->{start_line} : undef;
    my $full       = exists $argref->{full} ? $argref->{full} : 0;
    my $no_file    = exists $argref->{no_file} ? $argref->{no_file} : 0;

    my @output = $no_file ? () : ('FILE = ' . $self->get_name());
    my %lines;
    my $tag_value;

    $lines{'FILE'} = $start_line++ if defined $start_line;

    foreach my $tag (sort keys %{$self})
    {
        next if $tag eq 'FILE'; # Already formatted
        if (!$full)
        {
            next if $tag =~ m/$calculated_tags_re/;
        }

        confess "Uninitialized value for tag \"$tag\"\n" if !defined($self->get_value($tag));
        
        $tag_value = $self->get_value($tag);
        if (ref $tag_value eq 'ARRAY')
        {
            my @values = (@{$tag_value}); # Make a copy
            my $value = shift @values;
            confess "Uninitialized array value for tag \"$tag\"\n" if !defined($value);
            push(@output, "$tag = $value");
            foreach $value (@values)
            {
                $value =~ s/(\r\n|\n|\r)/$1  /g;
                push(@output, "$tag += $value");
            }
        }
        else
        {
            $tag_value =~ s/(\r\n|\n|\r)/$1  /g;
            push(@output, "$tag = $tag_value");
        }
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

# Removes all calculated tags (according to the strict definition).
sub purge
{
    my $self = shift;

    foreach my $tag (sort keys %{$self})
    {
        delete $self->{$tag} if $tag =~ m/$strict_calc_tag_re/;
    }

    return;
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
        $this_val = $self->get_flattened_value($tag);
        $other_val = $other->get_flattened_value($tag);
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
