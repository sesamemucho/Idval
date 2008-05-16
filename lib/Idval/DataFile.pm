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

# package Idval::DataFile::Block;
# use Data::Dumper;
# use Carp;

# sub new
# {
#     my $class = shift;
#     my $self = {};
#     bless($self, ref($class) || $class);
#     $self->_init(@_);
#     return $self;
# }

# sub _init
# {
#     my $self = shift;
#     my $block_data = shift;
#     #my $starting_line = shift;
#     $self->{DATA} = $block_data;
#     #$self->{LINE} = $starting_line;
# }

# package Idval::DataFile::BlockReader;
# use Data::Dumper;
# use Carp;
# use Text::Balanced qw (
#                        extract_delimited
#                        extract_multiple
#                       );

# use Idval::FileIO;

# sub new
# {
#     my $class = shift;
#     my $self = {};
#     bless($self, ref($class) || $class);
#     $self->_init(@_);
#     return $self;
# }

# sub _init
# {
#     my $self = shift;
#     my @args = @_;
#     $self->{DATA} = {};
#     #$self->{CURRENT_LINE} = 1;
#     #$self->{BLOCK_SIZE} = 0;
# }

# sub get_keyword_set
# {
#     my $self = shift;

#     return 'SELECT|TAGNAME|VALUE';
# }

# sub split_value
# {
#     my $self = shift;
#     my $value = shift;
#     my @retlist;

#     # This would be a lot prettier if I could figure out how to use Balanced::Text correctly...
#     my @fields = extract_multiple($value,
#                                   [
#                                    sub { extract_delimited($_[0],q{'"})},
#                                   ]);

#     foreach my $field (@fields)
#     {
#         $field =~ s/^\s+//;
#         $field =~ s/\s+$//;
#         if ($field =~ m/[''""]/)
#         {
#             $field =~ s/^[''""]//;
#             $field =~ s/[''""]$//;
#             push(@retlist, $field);
#         }
#         else
#         {
#             push(@retlist, split(' ', $field));
#         }
#     }

#     return \@retlist;
# }

# sub store_value
# {
#     my $self = shift;
#     my $op = shift;
#     my $name = shift;
#     my $value = shift;

#     #print STDERR "Storing \"$value\" in \"$name\"\n";
#     if (exists $self->{DATA}->{$name})
#     {
#         $value =~ s/[\n\r]//g;
#         if ($value)
#         {
#             $value =~ s/^\s*/\n    /;
#             $self->{DATA}->{$name} .= $value;
#         }
#     }
#     else
#     {
#         $self->{DATA}->{$name} = $value;
#     }
# }

# # sub store_keyword_value
# # {
# #     my $self = shift;
# #     my $kw = shift;
# #     my $name = shift;
# #     my $op = shift;
# #     my $value = shift;

# #     push(@{$self->{DATA}->{KEYWORDS}->{$kw}}, [$name, $op, $value]);
# # }

# # Split the input text into blocks and return a list
# sub get_blocks
# {
#    my $self = shift;
#    my $text = shift;

#    return split(/\n\n/, $text);
# }

# # Make a copy and return that
# sub get_block
# {
#     my $self = shift;
#     #my $line_num = 0;

#     croak "Unrecognized file contents: no \"FILE\" found.\n" unless exists $self->{DATA}->{FILE};

#     my $rec = Idval::Record->new($self->{DATA}->{FILE});
#     foreach my $key (keys %{$self->{DATA}})
#     {
#         if ($key eq 'FILE')
#         {
#             # The key already exists, so don't add it
#             # But count it
#             #$line_num++;
#             next;
#         }
#         $rec->add_tag($key, $self->{DATA}->{$key});
#         #$line_num++;
#     }

#     #$rec->add_tag('__LINE', $self->{CURRENT_LINE});
#     #$self->{CURRENT_LINE} += $line_num + 2; # Blocks are separated by one blank line,
#     # plus one more for the __LINE tag itself

#     #print STDERR "Rec for $self->{DATA}->{FILE}:", Dumper($rec);
#     return $rec;
# }

# sub add_block
# {
#     my $self = shift;
#     my $collection = shift;
#     my $block = shift;

#     #print STDERR "To \"", $block->get_name(), "\", adding <", join("; ", $block->format_record()), ">\n";
#     $collection->{$block->get_name()} = $block;
# }

# sub start_block
# {
#     my $self = shift;
#     my $text = shift;

#     $self->{BLOCK_SIZE} = $text =~ tr/\n/\n/;
#     # Clear the block data so the next block can start fresh
#     $self->{DATA} = {};
# }

# sub collection_type
# {
#     my $self = shift;

#     return 'HASH';
# }

# package Idval::DataFile;

#use base qw( Idval::Config::Block );

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

# sub _init
# {
#     my $self = shift;

#     my $reader = Idval::DataFile::BlockReader->new();
#     my $parser = Idval::FileParse->new($reader, @_);
#     $self->{BLOCKS} = $parser->parse();
#     #print STDERR Dumper($self);
# }

# sub get_reclist
# {
#     my $self = shift;

#     return $self->{BLOCKS};
# }

sub _init
{
    my $self = shift;
    $self->{DATAFILE} = shift;
    $self->{BLOCKS} = $self->parse();
}

sub parse
{
    my $self = shift;

    my $datafile = $self->{DATAFILE};
    my $collection = Idval::Collection->new();
    if (not $datafile)
    {
        $self->{BLOCKS} = $collection;
        return $collection;
    }

    my $fh = Idval::FileIO->new($datafile, "r") || croak "Can't open tag data file \"$datafile\" for reading: $!\n";

    my $accumulate_line = '';
    my @block = ();
    my $line;
    while(defined($line = <$fh>))
    {
        chomp $line;
        next if $line =~ m/^#/;
        if ($line =~ m/^\s*$/)
        {
            push(@block, $accumulate_line) if $accumulate_line;
            $collection->add($self->parse_block(\@block)) if @block;
            @block = ();
            $accumulate_line = '';
            next;
        }

        if ($line =~ m/^  (.*)/)
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
        if ($line =~ m/^([^=\s]+)\s*=\s*(.*)$/)
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

    my $rec = new Idval::Record($hash{FILE});
    foreach my $key (keys %hash)
    {
        # The key already exists, so don't add it
        next if ($key eq 'FILE');
        $rec->add_tag($key, $hash{$key});
    }

    #print "Returning ", Dumper($rec);
    $rec->commit_tags();
    return $rec;
}

sub get_reclist
{
    my $self = shift;

    #print "2: ", Dumper($self);
    #print "2: ref ", ref $self->{BLOCKS}, "\n";
    return $self->{BLOCKS};
}

1;
