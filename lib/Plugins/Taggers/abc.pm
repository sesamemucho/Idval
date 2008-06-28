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

    $self->set_param('path', '(Builtin)');
    $self->set_param('is_ok', 1);
    $self->set_param('status', 'ok');

    my $config = Idval::Common::get_common_object('config');
    $self->{VISIBLE_SEPARATOR} = $config->get_single_value('visible_separator', {'config_group' => 'idval_settings'});

    return;
}

sub read_tags
{
    my $self = shift;
    my $tag_record = shift;
    my $line;
    my $current_tag;
    my $fileid = $tag_record->get_value('FILE');

    my ($tags) = $self->parse_file($fileid);
    my $taginfo;

    foreach my $key (keys %{$tags})
    {
        my @tag_value_list = @{$tags->{$key}};
        $taginfo = scalar(@tag_value_list) == 1 ? $tag_value_list[0] : \@tag_value_list;
        $tag_record->add_tag($key, $taginfo);
    }

    return 0;
}

sub write_tags
{
    my $self = shift;
    my $tag_record = shift;

    return 0 if !$self->query('is_ok');

    my $fileid = $tag_record->get_value('FILE');

    my ($tags, $fname, $id) = $self->parse_file($fileid);

    if (!exists($self->{OUTPUT}->{$fname}))
    {
        $self->{OUTPUT}->{$fname} = $self->{TEXT}->{$fname}->{PREFACE};
    }

    # For each field found in the file,
    # check it against the tag_record. If the field is not in the tag record, 
    # delete it from the file. If the field is in the tag record, replace it.
    my $text = $self->{TEXT}->{$fname}->{BLOCK}->{$id};
    my $field_id;
    my $output = '';
    my $temp_rec = Idval::Record->new({Record=>$tag_record});
    my $tag_value;

  LOOP2:
    {
        if ($text =~ m/\G([ABCDFGHIKLMmNOPQRrSTUVWXZ]):.*?([\r\n]+)/gsc)
        {
            $field_id = $1;
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

    $self->{OUTPUT}->{$fname} .= $output;

    return 1;
}

sub parse_file
{
    my $self = shift;
    my $fileid = shift;
    my $vs = $self->{VISIBLE_SEPARATOR};

    my ($fname, $id) = ($fileid =~ m/^(.*)\Q$vs\E(\d+)/);

    if (!exists($self->{TEXT}->{$fname}))
    {
        my $fh = Idval::FileIO->new($fname, "r") || croak "Can't open \"$fname\" for reading: $!\n";
        my $text = do { local $/ = undef; <$fh> };
        $fh->close();

      LOOP:
        {
            $self->{TEXT}->{$fname}->{DIRTY} = 0;
            $self->{TEXT}->{$fname}->{PREFACE} = $1, redo LOOP if $text =~ m/\G^(.*?[\r\n]+\s*)?(?=X:)/gsc;
            if ($text =~ m/\G(X:\s*(\d+).*?)(?=X:|\z)/gsc)
            {
                $self->{TEXT}->{$fname}->{BLOCK}->{sprintf("%04d", $2)} = $1;
                redo LOOP;
            }
        }

        #print Dumper($self->{TEXT});
    }
    
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

#     if ($id eq '0001')
#     {
#         my $foo_text;
#         print "Block: <$text>\n";
#         ($foo_text = $text) =~ tr/\r\n/^%/;
#         print "Foo block: <$foo_text>\n";
#     }
  LOOP2:
    {
        if ($text =~ m/\G^([ABCDFGHIKLMmNOPQRrSTUVWXZ]):(.*)$/gmc)
        {
            my $fieldid = $1;
            my $tagvalue = $2;
            {
                my $text1 = $tagvalue;
                $text1 =~ s/\r//g;
                #print "Parsing: Field $fieldid, text <$text1>\n";
            }
            push(@{$tags{$fieldid}}, $tagvalue);
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

            my $rec = Idval::Record->new({FILE=>sprintf("%s%04d", $path . '%%', $item),
                                          CLASS=>$class, TYPE=>$type});
            $srclist->add($rec);
        };
    }


    return;
}

sub close
{
    my $self = shift;
    my $fh;

    # Remove all cached file info
    $self->{TEXT} = {};

    if (exists($self->{OUTPUT}))
    {
        foreach my $fname (keys %{$self->{OUTPUT}})
        {
            $fh = Idval::FileIO->new($fname . "-new", "w") || croak "Can't open \"$fname\" for writing: $!\n";
            $fh->print($self->{OUTPUT}->{$fname});
            $fh->close();
        }

        $self->{OUTPUT} = {};
        delete $self->{OUTPUT};
    }
}

sub glabber
{
    my $self = shift;

    print "Hello from glabber\n";
}

1;
