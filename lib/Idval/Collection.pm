package Idval::Collection;

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

use Idval::Logger qw(fatal);
use Idval::Common;

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
    my $argref = shift || {};

    my $contents    = exists $argref->{contents} ? $argref->{contents} : '';
    $self->{SOURCE} = ! exists $argref->{source} ? 'UNKNOWN'
                    : $argref->{source}          ? $argref->{source}
                    : 'UNKNOWN'
                    ;

    # Set the default encoding according to the current Perl input encoding
    $self->{ID3_ENCODING} = ${^UNICODE} & 8 ? 'unicode' : 'iso-8859-1';
    $self->{CREATIONDATE} = scalar(localtime());

    if ($contents and ref($contents) eq 'Idval::Collection')
    {
        $self->{SOURCE} = $contents->{SOURCE};
        $self->{CREATIONDATE} = $contents->{CREATIONDATE};
        $self->{ID3_ENCODING} = $contents->{ID3_ENCODING};
        $self->{RECORDS} = $contents->{RECORDS};
    }
    elsif ($contents and ref($contents) eq 'HASH')
    {
        $self->{RECORDS} = $contents;
    }
    else
    {
        $self->{RECORDS} = {};
    }

    Idval::Common::register_common_object('id3_encoding', $self->{ID3_ENCODING});

    return;
}

sub add
{
    my $self = shift;
    my $tag_record = shift;
    #print "Adding ", Dumper($tag_record);
    #print "ref record: ", ref $tag_record, "\n";
    #print "name: ", $tag_record->get_name(), "\n";
    my $name = $tag_record->get_name();
    $self->{RECORDS}->{$name} = $tag_record;

    return;
}

sub get
{
    my $self = shift;
    my $name = shift;

    return $self->{RECORDS}->{$name};
}

sub get_keys
{
    my $self = shift;

    return sort keys %{$self->{RECORDS}};
}

sub get_diff_keys
{
    my $self = shift;

    return $self->get_keys();
}

sub stringify
{
    my $self = shift;
    my $full = shift || 0;

    my @output = ();
    my @reclist;
    fatal("Huh?") unless defined $self->{CREATIONDATE};
    my $date = $self->{CREATIONDATE};

    push(@output, "# IDValidator Tag File (DO NOT REMOVE THIS LINE)");
    push(@output, "created_on: " . $date);
    push(@output, "source: " . $self->{SOURCE});
    push(@output, "encoding: " . $self->{ID3_ENCODING});
    push(@output, "");

    my $lineno = 5;
    foreach my $fname ($self->get_keys())
    {
        # The __LINE tag is used only in cmd_validate
        #$self->{RECORDS}->{$fname}->{__LINE} = $lineno; # Side effect!
        @reclist = $self->{RECORDS}->{$fname}->format_record({start_line => $lineno, full => $full});
        push(@output, @reclist);
        #print "line $lineno for \"", $self->{RECORDS}->{$fname}->get_name(), "\"\n";
        #print "Lines for ", $self->{RECORDS}->{$fname}->get_name(), Dumper($self->{RECORDS}->{$fname}->{__LINES});
        #$lineno += scalar(@reclist);
        $lineno = $self->{RECORDS}->{$fname}->{__NEXT_LINE};
    }

    return \@output;
}

sub source
{
    my $self = shift;
    my $source = shift;

    $self->{SOURCE} = $source if defined $source;

    return $self->{SOURCE};
}

sub get_value
{
    my $self = shift;
    my $key = shift;

    return $self->{RECORDS}->{$key};
}

# sub get_all_keys
# {
#     my $self = shift;
#     return sort keys %{$self->{RECORDS}};
# }

sub key_exists
{
    my $self = shift;
    my $key = shift;

    return exists($self->{RECORDS}->{$key});
}

sub coll_map
{
    my $self = shift;
    my $subr = shift;
    my @retval;

    foreach my $key ($self->get_keys())
    {
        push(@retval, &$subr($self->get($key)));
    }

    return \@retval;
}

sub purge
{
    my $self = shift;

    $self->coll_map(sub {my $rec = shift; $rec->purge(); });

    return;
}

1;
