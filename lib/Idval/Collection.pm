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

    $self->{CREATIONDATE} = scalar(localtime());

    if ($contents and ref($contents) eq 'Idval::Collection')
    {
        $self->{SOURCE} = $contents->{SOURCE};
        $self->{CREATIONDATE} = $contents->{CREATIONDATE};
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

    return;
}

sub add
{
    my $self = shift;
    my $record = shift;
    #print "Adding ", Dumper($record);
    #print "ref record: ", ref $record, "\n";
    #print "name: ", $record->get_name(), "\n";
    my $name = $record->get_name();
    $self->{RECORDS}->{$name} = $record;
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

sub stringify
{
    my $self = shift;
    my @output = ();
    my @reclist;
    my $date = $self->{CREATIONDATE};

    push(@output, "# IDValidator Tag File (DO NOT REMOVE THIS LINE)");
    push(@output, "# Created on: " . $date);
    push(@output, "# Source: " . $self->{SOURCE});
    push(@output, "");

    my $lineno = 5;
    foreach my $fname ($self->get_keys())
    {
        # The __LINE tag is used only in cmd_validate
        #$self->{RECORDS}->{$fname}->{__LINE} = $lineno; # Side effect!
        @reclist = $self->{RECORDS}->{$fname}->format_record($lineno);
        push(@output, @reclist);
        #print "line $lineno for \"", $self->{RECORDS}->{$fname}->get_name(), "\"\n";
        #print "Lines for ", $self->{RECORDS}->{$fname}->get_name(), Dumper($self->{RECORDS}->{$fname}->{__LINES});
        #$lineno += scalar(@reclist);
        $lineno = $self->{RECORDS}->{$fname}->{__NEXT_LINE};
    }

    return \@output;
}

sub get_source
{
    my $self = shift;

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

# sub size
# {
#     my $self = shift;
#     return scalar keys %{$self->{RECORDS}};
# }

# sub get_records
# {
#     my $self = shift;
#     my $fname;
#     my @retval;

#     foreach $fname ($self->getfnames()) {
#         push(@retval, $self->get_rec($fname));
#     }

#     return @retval;
# }

#
# Given a list of tag names for sort keys, build a function to sort the data by these keys
#
# The data is assumed to be in a Idval::Collection named "$self".
#
# sub make_sort_function
# {
#     my $self = shift;
#     my @tags = @_;
#     my $tag;
#     my $tagindex = 2;
#     my $sortcmd;

#     $sortcmd = 'map { $_->[0] }' . "\nsort {";

#     foreach $tag (@tags)
#     {
#         $sortcmd .= "\$a->[$tagindex] cmp \$b->[$tagindex] ||\n";
#         $tagindex++;
#     }

#     # Finish up by sorting according to file name
#     $sortcmd .= "\$a->[1] cmp \$b->[1]\n} map { [\$_, \$_->get_fullname()";

#     foreach $tag (@tags)
#     {
#         $sortcmd .= ", \$_->get_tag_value('$tag', '-UNDEFOK'=>0)";
#     }

#     $sortcmd .= "]} \$self->getrecords()";

#     return $sortcmd;
# }

# sub sort_by_tag
# {
#     my $self = shift;
#     my @tags = @_;

#     my $rec;
#     my $sortcmd = $self->make_sort_function(@tags);
#     my @sortedrecs = eval $sortcmd;

#     return @sortedrecs;
# }

# sub stringify
# {
#     my $self = shift;
#     my %args = (
#                 -SORTBY => [],
#                 -PRINTNUMBERS => 0,
#                 -ALLTAGS => 0,
#                 -ADDDATE => 1,
#                 @_,
#                );

#     my @sort_tags = @{$args{'-SORTBY'}};

#     $log->debug1("sort_tags: ", join(",", @sort_tags), "\n");
#     my $rec;
#     my @output = ();
#     my $date = $args{'-ADDDATE'} ? $self->{CREATIONDATE} : "";

#     push(@output, "# IDValidator Tag File (DO NOT REMOVE THIS LINE)");
#     push(@output, "# Created on: " . $date);
#     push(@output, "# Source: " . $self->{SOURCE});

#     foreach $rec ($self->sort_by_tag(@sort_tags)) {
#         $log->debug2("Rec ", $rec->get_fullname(), "\n");
#         $log->debug2("Rec ", join(": ", $rec->get_tag_names(%args)), "\n");
#         push(@output, $rec->format_record(%args));
#     }

#     return \@output;
# }

1;
