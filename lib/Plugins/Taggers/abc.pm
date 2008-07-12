package Idval::SysPlugins::Taggers::Abc;

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

    $self->{FWD_MAPPING} = $config->merge_blocks({'config_group' => 'tag_mappings',
                                                  'type' => 'ABC'
                                                 });

    $self->{REV_MAPPING} = map { $self->{FWD_MAPPING}->{$_} => $_ } keys %{$self->{FWD_MAPPING}};

    $self->save_info();
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

        if (exists $self->{FWD_MAPPING}->{$key})
        {
            $tag_record->add_tag($self->{FWD_MAPPING}->{$key}, $taginfo);
        }
        else
        {
            $tag_record->add_tag($key, $taginfo);
        }
    }

    return 0;
}

sub write_tags
{
    my $self = shift;
    my $tag_record = shift;
    my $eol;

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
    my $field_value;
    my $output = '';
    my $tune = '';
    my $temp_rec = Idval::Record->new({Record=>$tag_record});
    my $tag_value;

    if ($id eq '0002')
    {
        print "Looking at <$text>\n";
        print Dumper($temp_rec);
    }

  LOOP2:
    {
        if ($text =~ m/\G([ABCDFGHIKLMmNOPQRrSTUVWXZ]):(.*?)(\s*%.*?)?([\r\n]+)/gsc)
        {
            $field_id = $1;
            $field_value = $2;
            my $field_comment = defined($3) ? $3 : '';
            $eol = $4;

            if (exists $self->{FWD_MAPPING}->{$field_id})
            {
                $tag_value = $temp_rec->shift_value($self->{FWD_MAPPING}->{$field_id});
            }
            else
            {
                $tag_value = $temp_rec->shift_value($field_id);
            }

            if (($field_id eq 'X') && ($field_value ne $tag_value))
            {
                carp("\nIn \"$fname\", attempt to change write-only tag \"$field_id\" from \"$field_value\" to \"$tag_value\" in section \"$fileid\"\n");
                return 1;
            }
                
            if ($tag_value)
            {
                $output .= $field_id . ':' . $tag_value . $field_comment . $eol;
            }
            redo LOOP2;
        }

        if ($text =~ m/\G^\%\%idv-(\S+)\s+(.*?)([\r\n]+)/gsc)
        {
            print "Checking 1 \"$text\"\n";
            # Transform these from ID3V2 tags, someday. TODO
            $field_id = uc $1;
            $field_value = $2;
            $eol = $3;
            $tag_value = $temp_rec->shift_value($field_id);
            if ($tag_value)
            {
                $output .= '%% idv-' . lc $field_id . ':' . $tag_value . $eol;
            }
            redo LOOP2;
        }

        if ($text =~ m/\G^\%\%([^-]+-\S+)\s+(.*?)([\r\n]+)/gsc)
        {
            print "Checking 2 \"$text\"\n";
            # Transform these from ID3V2 tags, someday. TODO
            $field_id = $1;
            $field_value = $2;
            $eol = $3;
            $tag_value = $temp_rec->shift_value($field_id);
            if ($tag_value)
            {
                $output .= '%%' . $field_id . ':' . $tag_value . $eol;
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
            $tune = $1;
            redo LOOP2;
        }
    }

    my $tagvalue;
    my $abc_id;
    # Are there any new '%%*' tags to add?
    foreach my $tag_id ($temp_rec->get_all_keys())
    {
        print "temp: checking key \"$tag_id\"\n";
        while ($tagvalue = $temp_rec->shift_value($tag_id))
        {
            # Do we have a special translation?
            if (exists($self->{REV_MAPPING}->{$tag_id}))
            {
                $abc_id = $self->{REV_MAPPING}->{$tag_id};
                print "Got translated tag \"$abc_id\", setting ", $temp_rec->get_value($tag_id), "\n";
                $output .= $abc_id . (length($abc_id) eq 1) ? ':' : '' . ' '. $temp_rec->get_value($tag_id) . $eol;
            }
            elsif ($tag_id =~ m/^[^-]+-/)
            {
                print "Got \"$tag_id\", setting ", $temp_rec->get_value($tag_id), "\n";
                # Let's hope an eol has been defined. TODO - make sure
                $output .= '%% ' . $tag_id . ' '. $temp_rec->get_value($tag_id) . $eol;
            }
            elsif ($tag_id =~ m/^../) # At least two chars and not an %%foo- tag
                # means it should be an idv- tag.
            {
                print "Got idv tag \"$tag_id\", setting ", $temp_rec->get_value($tag_id), "\n";
                # Let's hope an eol has been defined. TODO - make sure
                $output .= '%% idv-' . lc $tag_id . ' '. $temp_rec->get_value($tag_id) . $eol;
            }
        }
    }

    if ($id eq '0002')
    {
        print "output is: \"$output\"\n";
    }

    $self->{OUTPUT}->{$fname} .= $output . $tune;

    return 0;
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
        if ($text =~ m/\G^([ABCDFGHIKLMmNOPQRrSTUVWXZ]):(.*?)(\s*%.*?)?$/gmc)
        {
            my $fieldid = $1;
            my $tagvalue = $2;
#             if($fieldid eq 'M')
#             {
#                 my $text1 = defined($3) ? $3 : 'undef';
#                 my $text2 = $tagvalue;
#                 $text1 =~ s/\r//g;
#                 $text2 =~ s/\r//g;
#                 print "Parsing: Field $fieldid, tagvalue <$text2>, comment <$text1>\n";
#             }
            push(@{$tags{$fieldid}}, $tagvalue);
            redo LOOP2;
        }

        if ($text =~ m/\G^\%\%idv-(\S+)\s+(.*)$/gmc)
        {
            # These should transform straight to IDV tags
            my $fieldid = uc $1;
            my $tagvalue = $2;
            {
                my $text1 = $tagvalue;
                $text1 =~ s/\r//g;
                print "Parsing: idv Field \"$fieldid\", text <$text1>\n";
            }
            push(@{$tags{$fieldid}}, $tagvalue);
            redo LOOP2;
        }

        if ($text =~ m/\G^\%\%([^-]+-\S+)\s+(.*)$/gmc)
        {
            my $fieldid = $1;
            my $tagvalue = $2;
            {
                my $text1 = $tagvalue;
                $text1 =~ s/\r//g;
                print "Parsing: other Field \"$fieldid\", text <$text1>\n";
            }
            push(@{$tags{$fieldid}}, $tagvalue);
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
            $fh = Idval::FileIO->new($fname, "w") || croak "Can't open \"$fname\" for writing: $!\n";
            $fh->printflush($self->{OUTPUT}->{$fname});
            $fh->close();
        }

        $self->{OUTPUT} = {};
        delete $self->{OUTPUT};
    }
}

sub save_info
{
    my $self = shift;
    my $help_file = Idval::Common::get_common_object('help_file');

    my $mappings = "Tag mappings:\n";

    foreach my $key (sort keys %{$self->{FWD_MAPPING}})
    {
        $mappings .=  sprintf("%20s => %-10s\n", $key, $self->{FWD_MAPPING}->{$key});
    }

    $help_file->detailed_info_ref('abc', __PACKAGE__, $mappings);

    return;
}

sub glabber
{
    my $self = shift;

    print "Hello from glabber\n";
}

1;
