package Idval::SysPlugins::Abc;

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

#use Idval::Setup;
use strict;
use warnings;
no  warnings qw(redefine);
use Class::ISA;
use Data::Dumper;
use Carp;

use Idval::FileIO;
use base qw(Idval::Plugin);

my $name = 'abc';
my $type = 'ABC';

Idval::Common::register_provider({provides=>'reads_tags', name=>$name, type=>$type});
Idval::Common::register_provider({provides=>'writes_tags', name=>$name, type=>$type});

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    print "****** ref self: ", ref $self, "\n";
    bless($self, ref($class) || $class);
    $self->init();
    return $self;
}

sub init
{
    my $self = shift;

    $self->set_param('name', $self->{NAME});
    $self->set_param('dot_map', {'ABC' => [qw{ a }]});
    $self->set_param('filetype_map', {'ABC' => [qw{ abc }]});
    $self->set_param('classtype_map', {'MUSIC' => [qw( ABC )]});
    $self->set_param('type', $type);

    #my $path = $self->find_exe_path();
    $self->set_param('path', '(Builtin)');
    $self->set_param('is_ok', 1);
    $self->set_param('status', 'ok');

    return;
}

sub read_tags
{
    my $self = shift;
    my $tag_record = shift;
    my $line;
    my $current_tag;
    #my $retval = 0;

    my $fileid = $tag_record->get_value('FILE');

    my ($tags) = $self->parse_file($fileid);
    my $taginfo;
    #print "read_tags: ", Dumper($tags);
    foreach my $key (keys %{$tags})
    {
        my @tag_value_list = @{$tags->{$key}};
        #$taginfo = scalar(@{$tags->{$key}}) == 1 ? ${$tags->{$key}}[0] : $tags->{$key};
        $taginfo = scalar(@tag_value_list) == 1 ? $tag_value_list[0] : \@tag_value_list;

        #print "key \"$key\" taginfo: ", Dumper($taginfo);
        $tag_record->add_tag($key, $taginfo);
    }

    $tag_record->commit_tags();

    return 0;
}

sub write_tags
{
    my $self = shift;
    my $tag_record = shift;

    #print Dumper($tag_record);
    return 0 if !$self->query('is_ok');

    my $fileid = $tag_record->get_value('FILE');

    my ($tags, $fname, $id) = $self->parse_file($fileid);


    # For each field found in the file,
    # check it against the tag_record. If the field is not in the tag record, 
    # delete it from the file. If the field is in the tag record, replace it.
    my $text = $self->{TEXT}->{$fname}->{BLOCK}->{$id};
#     my $ft_index;
#     my $ft_len;
#     my $file_tag;
    my $field_id;
    my $foo_text;
    #($foo_text = $text) =~ tr/\r\n/^%/;
    #print "1 text  : <$foo_text>\n";
    my $output = '';
    my $temp_rec = Idval::Record->new($tag_record);
    #print "Temp_tag: ", Dumper($tag_record);
    my $tag_value;

  LOOP2:
    {
        if ($text =~ m/\G([ABCDFGHIKLMmNOPQRrSTUVWXZ]):.*?([\r\n]+)/gsc)
        {
            $field_id = $1;
            #print "Field $1, text <$2>\n";
            $tag_value = $temp_rec->shift_value($field_id);
            if ($tag_value)
            {
                $output .= $field_id . ':' . $tag_value . $2;
            }
            redo LOOP2;
        }

        if ($text =~ m/\G[\r\n]+/gsc)
        {
            #print "Got new line\n";
            redo LOOP2;
        }

        if ($text =~ m/\G(.+)/gsc)
        {
            # The tune (most likely)
            $output .= $1;
            redo LOOP2;
        }
    }

#     foreach my $line (split(/[\r\n]+/, $text))
#     {
#         if ($line =~ m/^([ABCDFGHIKLMmNOPQRrSTUVWXZ]):.*([\r\n]+)/)
#         {
#             $field_id = $1;
#             $tag_value = $temp_rec->pop_value($field_id);
#             if ($tag_value)
#             {
#                 $output .= $field_id . ':' . $tag_value . $2;
#             }
#             next;
#         }

#         $output .= $line;
#     }

    if ($text eq $output)
    {
        print "OK\n";
    }
    else
    {
        print "Pfui!\n";
        ($foo_text = $text) =~ tr/\r\n/^%/;
        print "1 text  : <$foo_text>\n";
        ($foo_text = $output) =~ tr/\r\n/^%/;
        print "2 output: <$foo_text>\n";
    }

#     foreach my $file_tag_id (keys %{$tags})
#     {
#         if(!$tag_record->key_exists($file_tag_id))
#         {
#             # Delete all instances
#         }
#         else
#         {
#             my $tag_field = $tag_record->get_value($file_tag_id);
#             $tag_field = [$tag_field] if ref $tag_field ne 'ARRAY';

#             # Number of items of this field id
#             $ft_len = scalar(@{$tags->{$file_tag_id}});
            
#             for($ft_index = 0; $ft_index < $ft_len; $ft_index++)
#             {
#                 my ($field_value, $startpos, $len) = @{${$tags->{$file_tag_id}}[$ft_index]};
#                 ($foo_text = $field_value) =~ tr/\r\n/^%/;
#                 print "field $file_tag_id; index $ft_index; info is: ($foo_text, $startpos, $len)\n";
#                 #print "tag field: ", Dumper($tag_field);
#                 if ($ft_index <= $#{$tag_field})
#                 {
#                     substr($text, $startpos, $len, $file_tag_id . ':' . $field_value);
#                 }
#                 else
#                 {
#                     print "*** Whoops! Shouldn't get here now (ft_index: $ft_index)\n";
#                     # We have run out of tag fields in the record; start deleting from the file
#                 }
#             }
#         }


#     }
#     ($foo_text = $text) =~ tr/\r\n/^%/;
#     print "2 text: <$foo_text>\n";



    #my $filename = $tag_record->get_value('FILE');
    my $status = 1;

    #print "For $filename, ", Dumper($tag_record);

#     my $path = $self->query('path');

#     Idval::Common::run($path, '--remove-all-tags', $filename);
#     my @taglist;
#     foreach my $tagname ($tag_record->get_all_keys())
#     {
#         push(@taglist, $tag_record->get_value_as_arg('--set-tag=' . $tagname . '=', $tagname));
#     }

#     my $status = Idval::Common::run($path,
#                                     @taglist,
#                                     $filename);

    return $status;
}

sub parse_file
{
    my $self = shift;
    my $fileid = shift;

    my ($fname, $id) = ($fileid =~ m/^(.*)%%(\d+)/);

    if (!exists($self->{TEXT}->{$fname}))
    {
        print "Parsing \"$fname\"\n";
        my $fh = Idval::FileIO->new($fname, "r") || croak "Can't open \"$fname\" for reading: $!\n";
        my $text = do { local $/ = undef; <$fh> };
        $fh->close();

      LOOP:
        {
            $self->{TEXT}->{$fname}->{DIRTY} = 0;
            $self->{TEXT}->{$fname}->{PREFACE} = $1, redo LOOP if $text =~ m/\G(^.*?\n\s*)(?=X:)/gsc;
            $self->{TEXT}->{$fname}->{BLOCK}->{sprintf("%04d", $2)} = $1, redo LOOP if $text =~ m/\G(X:\s*(\d+).*?)(?=X:|\z)/gsc;
        }

        #print Dumper($self->{TEXT});
    }
    
    #print "Checking block $id\n";

    my $text = $self->{TEXT}->{$fname}->{BLOCK}->{$id};
    $text =~ s/\r//g;
    #print "\nFile $fileid:\n";
    my $field;
    my $data;
    my %tags;
    my $lastpos = 0;

    # We don't need to keep track of the order of fields here. If this
    # information is used to update an existing abc file, get the
    # order from that. Otherwise, just do what seems right and
    # syntactically correct.

    if ($id eq '0001')
    {
        my $foo_text;
        print "Block: <$text>\n";
        ($foo_text = $text) =~ tr/\r\n/^%/;
        print "Foo block: <$foo_text>\n";
    }
  LOOP2:
    {
        if ($text =~ m/\G^([ABCDFGHIKLMmNOPQRrSTUVWXZ]):(.*)$/gmc)
        {
            #print "Field $1, text <$2>\n";
            push(@{$tags{$1}}, $2);
#             push(@{$tags{$1}}, [$2, $lastpos, pos($text) - $lastpos]);
#             $lastpos = pos($text);

            redo LOOP2;
        }

        if ($text =~ m/\G[\r\n]+/gsc)
        {
            #print "Got new line\n";
            redo LOOP2;
        }

        if ($text =~ m/\G(.+)/gsc)
        {
            # The tune (most likely)
            redo LOOP2;
        }
    }

    #print "Got", Dumper(\%tags);

    return (\%tags, $fname, $id);
}

sub create_records
{
    my $self = shift;
    my $arglist = shift;

    my $fname   = $arglist->{filename};
    my $path    = $arglist->{path};
    my $class   = $arglist->{class};
    my $type    = $arglist->{type};
    my $srclist = $arglist->{srclist};

    my $fh = Idval::FileIO->new($fname, "r") || croak "Can't open \"$fname\" for reading: $!\n";
    my $text = do { local $/ = undef; <$fh> };
    $fh->close();

    my $item;

    foreach my $line (split("\n", $text))
    {
        $line =~ m/^X:(\d+)/x and do {
            $item = $1;

            my $rec = Idval::Record->new(sprintf("%s%04d", $path . '%%', $item));
            $rec->add_tag('CLASS', $class);
            $rec->add_tag('TYPE', $type);

            $srclist->add($rec);
        };
    }


    return;
}

sub close
{
    my $self = shift;

    # Remove all cached file info
    $self->{TEXT} = {};
}

sub glabber
{
    my $self = shift;

    print "Hello from glabber\n";
}

1;
