package Idval::DataFile;

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
use IO::File;
use Text::Balanced qw (
                       extract_tagged
                      );
use Idval::FileParse;
use Idval::Common;
use Idval::Record;
use Idval::Collection;

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
    $self->{DATAFILE} = shift;
    $self->{TYPEMAP} = Idval::Common::get_common_object('typemap');
    $self->{BLOCKS} = $self->parse();

    return;
}

sub parse
{
    my $self = shift;

    my $datafile = $self->{DATAFILE};
    my $collection = Idval::Collection->new({'source' => $datafile});
    if (not $datafile)
    {
        $self->{BLOCKS} = $collection;
        return $collection;
    }

    my $fh = Idval::FileIO->new($datafile, "r") || croak "Can't open tag data file \"$datafile\" for reading: $!\n";

    my $line;

    # Get the data related to the collection itself
    while(defined($line = <$fh>))
    {
        chomp $line;
        next if $line =~ m/^\#/x;
        # A blank line delimits this header information block
        last if $line =~ m/^\s*$/;

        $line =~ m{ ^created_on:\s+(.*?)$ }x and do {
            $collection->{CREATIONDATE} = $1;
            next;
        };

        $line =~ m{ ^source:\s+(.*?)$ }x and do {
            $collection->{SOURCE} = $1;
            next;
        };

        $line =~ m{ ^encoding:\s+(.*?)$ }x and do {
            $collection->{ID3_ENCODING} = $1;
            next;
        };

    }

    my $accumulate_line = '';
    my @block = ();
    while(defined($line = <$fh>))
    {
        chomp $line;
        next if $line =~ m/^\#/x;
        if (($line =~ m/^\s*$/x) || eof)
        {
            push(@block, $accumulate_line) if $accumulate_line;
            push(@block, $line) if (eof && $line);
            $collection->add($self->parse_block(\@block)) if @block;
            @block = ();
            $accumulate_line = '';
            next;
        }

        if ($line =~ m/^\ \ (.*)/x)
        {
            $accumulate_line .= "\n" . $1;
        }
        else
        {
            push(@block, $accumulate_line) if $accumulate_line;
            $accumulate_line = $line;
        }
    }

    $fh->close();

    $self->{BLOCKS} = $collection;
    return $collection;
}

sub parse_block
{
    my $self = shift;
    my $blockref = shift;
    my %hash;

    foreach my $line (@{$blockref})
    {
        if ($line =~ m/\A([^=\s]+)\s*\+=\s*(.*)\z/msx)
        {
            if (!exists ($hash{$1}))
            {
                croak "\"Append\" line too early in tag data file (no previous value): \"$line\"\n";
            }
            elsif (ref $hash{$1} ne 'ARRAY')
            {
                $hash{$1} = [$hash{$1}, $2];
            }
            else
            {
                push(@{$hash{$1}}, $2);
            }
        }
        elsif ($line =~ m/\A([^=\s]+)\s*=\s*(.*)\z/msx)
        {
            $hash{$1} = $2;
        }
        else
        {
            croak "Unrecognized line in tag data file: \"$line\"\n";
        }
    }

    if (!exists($hash{FILE}))
    {
        croak "No FILE tag in tag data record \"", join("\n", @{$blockref}), "\"\n";
    }

    my $rec = Idval::Record->new({FILE=>$hash{FILE}});

    if (!exists($hash{TYPE}))
    {
        # Make a guess
        my $filetype = $self->{TYPEMAP}->get_filetype_from_file($hash{FILE});
        if ($filetype)
        {
            $rec->add_tag('TYPE', $filetype);
            $rec->add_tag('CLASS', $self->{TYPEMAP}->get_class_from_filetype($filetype));
        }
    }
    elsif (!exists($hash{CLASS}))
    {
        # TYPE exists, but not CLASS, so fill it in
        $rec->add_tag('CLASS', $self->{TYPEMAP}->get_class_from_filetype($hash{TYPE}));
    }
    # A CLASS tag without a TYPE tag is anomalous, but don't deal with it here.

    foreach my $key (keys %hash)
    {
        # The key already exists, so don't add it
        next if ($key eq 'FILE');
        #print STDERR "Adding key \"$key\", value \"$hash{$key}\"\n";
        $rec->add_tag($key, $hash{$key});
    }

    $rec->commit_tags();
    #print STDERR "Returning ", Dumper($rec);
    return $rec;
}

sub get_reclist
{
    my $self = shift;

    #print STDERR "2: ", Dumper($self);
    #print STDERR "2: ref ", ref $self->{BLOCKS}, "\n";
    return $self->{BLOCKS};
}

1;
