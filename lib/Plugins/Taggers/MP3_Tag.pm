package Idval::SysPlugins::MP3_Tag;

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
use Carp;
use Data::Dumper;

use base qw(Idval::Plugin);

my $req_status = eval {require MP3::Tag};
my $req_msg = !defined($req_status) ? "$!" :
                   $req_status == 0 ? "$@" :
                                       "Load OK";

if ($req_msg ne 'Load OK')
{
    print "Oops; let's try again for MP3::Tag\n";
    use lib Idval::Common::get_top_dir('lib/perl/MP3-Tag');

    $req_status = eval {require MP3::Tag};
    $req_msg = 'Load OK' if (defined($req_status) && ($req_status != 0));
}

my $name = 'MP3_Tag';
my $type = 'MP3';

Idval::Common::register_provider({provides=>'reads_tags', name=>$name, type=>$type, weight=>50});
Idval::Common::register_provider({provides=>'writes_tags', name=>$name, type=>$type, weight=>50});

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
    $self->set_param('dot_map', {'MP3' => [qw{ m }]});
    $self->set_param('filetype_map', {'MP3' => [qw{ mp3 }]});
    $self->set_param('classtype_map', {'MUSIC' => [qw( MP3 )]});

    $self->set_param('path', "(Perl module}");
    $self->set_param('is_ok', $req_msg eq "Load OK");
    if ($req_msg eq "No such file or directory")
    {
        $req_msg = "Perl module MP3::Tag not found";
    }
    $self->set_param('status', $req_msg);

    my $config = Idval::Common::get_common_object('config');
    $self->{VISIBLE_SEPARATOR} = $config->get_single_value('visible_separator', {'config_group' => 'idval_settings'});
    $self->{MELD_MP3_TAGS} = $config->get_single_value('meld_mp3_tags', {'config_group' => 'idval_settings'}, 1);

    return;
}

sub read_tags
{
    my $self = shift;
    my $tag_record = shift;
    my $line;
    my $current_tag;
    my $retval = 0;

    return $retval if !$self->query('is_ok');

    my $filename = $tag_record->get_value('FILE');

    my $mp3 = MP3::Tag->new($filename);

    $mp3->get_tags();
    my ($title, $track, $artist, $album, $comment, $year, $genre);

    if (exists $mp3->{ID3v1})
    {
        ($title, $artist, $album, $year, $comment, $track, $genre) = $mp3->{ID3v1}->all;
        $tag_record->add_tag('TITLE', $title);
        $tag_record->add_tag('TRACK', $track);
        $tag_record->add_tag('ARTIST', $artist);
        $tag_record->add_tag('ALBUM', $album);
        $tag_record->add_tag('COMMENT', $comment);
        $tag_record->add_tag('YEAR', $year);
        $tag_record->add_tag('GENRE', $genre);
    }

    my $frameIDs_hash = {};

    if (exists $mp3->{ID3v2})
    {
        if (!exists($self->{SUPPORTED_TAGS}))
        {
            $self->{SUPPORTED_TAGS} = $mp3->{ID3v2}->supported_frames();
        }

        $frameIDs_hash = $mp3->{ID3v2}->get_frame_ids('truename');
        my $valstr = '';

        foreach my $frame (keys %$frameIDs_hash)
        {
            #print ">>> $frame:\n";
            my @tagvalues = ();
#             if ($frame eq 'GEOB' or
#                 $frame eq 'PRIV' or
#                 $frame eq 'APIC' or
#                 $frame eq 'NCON')
#             {
#                 print "Got a \"$frame\" tag\n";
#                 $tagvalues[0] = '%placeholder%';
#             }
#             else
            {
                #my ($info_item, $name, @rest) = $mp3->{ID3v2}->get_frame($frame);
                my ($info_item, $name, @rest) = $mp3->{ID3v2}->get_frame($frame, 'array_nokey');
                #print "<<<<GOT AN ARRAY>>>\n" if scalar @rest;
                print "Frame $frame, info_item: ", Dumper($info_item);
                print "Frame $frame, rest: ", Dumper(\@rest);
                if (!defined($name))
                {
                    $tagvalues[0] = '%placeholder%';
                }
#                 elsif ($frame eq 'GEOB' or
#                        $frame eq 'PRIV' or
#                        $frame eq 'APIC' or
#                        $frame eq 'NCON')
#                 {
#                      $tagvalues[0] = '%placeholder%';
#                 }
                else
                {
                    for my $info ($info_item, @rest)
                    {
                        if (ref $info)
                        {
                            if ($$info[1] =~ m/^idv-(.*)/)
                            {
                                # This was a tag that was wrapped into a TXXX tag.
                                # Unwrap it here and store it in the record.
                                $tag_record->add_tag($1, $$info[2]);
                                next;
                            }
                            elsif ($frame eq 'GEOB' or
                                   $frame eq 'PRIV' or
                                   $frame eq 'APIC' or
                                   $frame eq 'NCON')
                            {
                                $valstr = '%placeholder%';
                            }
                            else
                            {
                                $valstr = join($self->{VISIBLE_SEPARATOR}, @{$info});
                            }
#                             #print "$name ($frame):\n";
#                             my @vals = ();
#                             while(my ($key,$val)=each %$info)
#                             {
#                                 #print " * $key => $val\n";
#                                 push(@vals, $val);
#                             }
#                             $valstr = join($self->{VISIBLE_SEPARATOR}, @vals);
                        }
                        else
                        {
                            #print "$name: $info\n";
                            $valstr = $info;
                        }
                        
                        my $text1;
                        ($text1 = $valstr) =~ s/\r/CR/g;
                        print "Frame $frame, valstr: \"$valstr\"\n";
                        push(@tagvalues, $valstr);
                    }
                }
            }

#             if (scalar(@tagvalues) > 1)
#             {
#                 print "<<< Got an array for file $filename, frame $frame\n";
#             }
            $tag_record->add_tag($frame, scalar @tagvalues == 1 ? $tagvalues[0] : \@tagvalues);
        }
    }

    return $retval;
}

sub write_tags
{
    my $self = shift;
    my $tag_record = shift;

    return 0 if !$self->query('is_ok');

    my $vs = $self->{VISIBLE_SEPARATOR};
    my $filename = $tag_record->get_name();

    my $temp_rec = Idval::Record->new({Record=>$tag_record});

    my $mp3 = MP3::Tag->new($filename);
    $mp3->get_tags();

    my $has_id3v1 = 0;
    my %id3v1_tags;

    print "MP3_Tag, processing \"$filename\"\n";
    foreach my $id3v1_key (qw(title track artist album comment year genre))
    {
        if ($temp_rec->key_exists(uc $id3v1_key))
        {
            $has_id3v1++;
            $id3v1_tags{$id3v1_key} = $temp_rec->shift_value(uc $id3v1_key);
        }
    }

    if ($has_id3v1)
    {
        my $id3v1 = exists($mp3->{ID3v1}) ? $mp3->{ID3v1} : $mp3->new_tag("ID3v1");
        foreach my $id3v1_key (keys %id3v1_tags)
        {
            $id3v1->artist( exists($id3v1_tags{$id3v1_key}) ? $id3v1_tags{$id3v1_key} : '') if $id3v1_key eq 'artist';
            $id3v1->album(  exists($id3v1_tags{$id3v1_key}) ? $id3v1_tags{$id3v1_key} : '') if $id3v1_key eq 'album';
            $id3v1->comment(exists($id3v1_tags{$id3v1_key}) ? $id3v1_tags{$id3v1_key} : '') if $id3v1_key eq 'comment';
            $id3v1->genre(  exists($id3v1_tags{$id3v1_key}) ? $id3v1_tags{$id3v1_key} : '') if $id3v1_key eq 'genre';
            $id3v1->title(  exists($id3v1_tags{$id3v1_key}) ? $id3v1_tags{$id3v1_key} : '') if $id3v1_key eq 'title';
            $id3v1->track(  exists($id3v1_tags{$id3v1_key}) ? $id3v1_tags{$id3v1_key} : '') if $id3v1_key eq 'track';
            $id3v1->year(   exists($id3v1_tags{$id3v1_key}) ? $id3v1_tags{$id3v1_key} : '') if $id3v1_key eq 'year';
        }

        $id3v1->write_tag();
    }

    my $id3v2 = exists($mp3->{ID3v2}) ? $mp3->{ID3v2} : $mp3->new_tag("ID3v2");

    if (!exists($self->{SUPPORTED_TAGS}))
    {
        $self->{SUPPORTED_TAGS} = $id3v2->supported_frames();
    }

    # Gather up the names of all the ID3v2 fields
    my $frameIDs = $id3v2->get_frame_ids();
    my $tagvalue;
    my @frameargs;
    my $tag_index;
    my $txxx_index = -1;
    my $framename;
    print "ID3v2:", Dumper($id3v2);

  TAG_LOOP:
    foreach my $tagname ($temp_rec->get_all_keys())
    {
        print "Checking \"$tagname\"\n";
        $tag_index = -1;
        while ($tagvalue = $temp_rec->shift_value($tagname))
        {
            $tag_index++;
            $framename = $tag_index > 0 ? sprintf("%s%02d", $tagname, $tag_index) : $tagname;

            print "Tag name is \"$tagname\"\n";
            if($tagvalue eq '%placeholder%') # Don't know how to handle; leave it be
            {
                delete $frameIDs->{$framename};
                next;
            }
            
            # Is the tag name a supported ID3v2 tag?
            if (exists($self->{SUPPORTED_TAGS}->{$tagname}))
            {
                if ($tagname eq 'TXXX')
                {
                    $txxx_index++;
                    $framename = $txxx_index > 0 ? sprintf("TXXX%02d", $txxx_index) : 'TXXX';
                }

                @frameargs = ($tagvalue =~ m/\Q$vs\E/) ? split(/\Q$vs\E/, $tagvalue) : ($tagvalue);
                print "Args for $framename are ", Dumper(\@frameargs);
            }
            else
            {
                # Nope - let's make a special TXXX idv tag
                $txxx_index++;
                $framename = $txxx_index > 0 ? sprintf("TXXX%02d", $txxx_index) : 'TXXX';
                @frameargs = (0, 'idv-' . $tagname, $tagvalue);
                #$id3v2->change_frame($txxx_index ? sprintf("TXXX%02d", $txxx_index) : 'TXXX', 0, 'idv-' . $tagname, $tagvalue);
            }


            # Does it already exist in the file?
            if (exists($frameIDs->{$framename}))
            {
                delete $frameIDs->{$framename};
                print "Tag $framename exists in file\n";
                $id3v2->change_frame($framename, @frameargs);
            }
            else
            {
                print "Tag $framename does not exist in file\n";
                $id3v2->add_frame($framename, @frameargs);
            }
        }
    }

    # Handle the leftover tags (they were in the file, but not in the tag record, so they should be deleted)
    foreach my $frameID (keys %{$frameIDs})
    {
        print "Removing $frameID\n";
        $id3v2->remove_frame($frameID);
    }

#     foreach my $tagname ($temp_rec->get_all_keys())
#     {
#         print "Checking \"$tagname\"\n";
#         # Does it already exist in the file?
#         if (exists($frameIDs->{$tagname}))
#         {
#             print "Tag $tagname exists in file\n";
#             while ($tagvalue = $temp_rec->shift_value($tagname))
#             {
#                 next if $tagvalue eq '%placeholder%'; # Don't know how to handle; leave it be
#                 @frameargs = ($tagvalue =~ m/\Q$vs\E/) ? split(/\Q$vs\E/, $tagvalue) : ($tagvalue);
#                 print "Calling change_frame for $tagname with ", Dumper(\@frameargs);
#                 $id3v2->change_frame($tagname, @frameargs);
#             }
#             next;
#         }
#         # Is it a known ID3v2 tag?
#         # Currently, the only way I can tell is to try and create it.
#         if (defined ($id3v2->add_frame($tagname)))
#         {
#             # Okey-dokey, back up and push
#             $id3v2->delete_frame($tagname);
#         }
#         else
#         {
#             next;
#         }

#         while ($tagvalue = $temp_rec->shift_value($tagname))
#         {
#             @frameargs = ($tagvalue =~ m/\Q$vs\E/) ? split(/\Q$vs\E/, $tagvalue) : ($tagvalue);
#             print "Calling add_frame for $tagname with ", Dumper(\@frameargs);
#             $id3v2->add_frame($tagname, @frameargs);
#         }
#     }

    $id3v2->write_tag();
    # Now, we should be left with all the tags that weren't ID3v1 or ID3v2

    print "Tags left: ", join(":", $temp_rec->format_record()), "\n";

    return 0;
}

1;
