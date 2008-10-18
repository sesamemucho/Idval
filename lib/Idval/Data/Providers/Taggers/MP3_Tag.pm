package Idval::Plugins::Taggers::MP3_Tag;

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
use Encode;

use base qw(Idval::Provider);

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
    $self->{CONFIG} = $config;

    $self->{VISIBLE_SEPARATOR} = $config->get_single_value('visible_separator', {'config_group' => 'idval_settings'});
    $self->{EXACT_TAGS} = $config->get_single_value('exact_tags', {'config_group' => 'idval_settings'});

    $self->{IS_ENCODABLE_REGEXP} = qr/^(?:T...|WXXX|IPLS|USLT|SYLT|COMM|GEOB|APIC|USER|OWNE|COMR)$/o;
    map {$self->{HAS_LANGUAGE_DESC}->{$_} = $_} qw(USLT SYLT COMM USER);

    # Forward mapping is ID3v1 to ID3v2
    # Reverse mapping is ID3v2 to ID3v1
    $self->{FWD_MAPPING} = $config->merge_blocks({'config_group' => 'tag_mappings',
                                                  'type' => 'MP3'
                                                 });

    foreach my $key (keys %{$self->{FWD_MAPPING}})
    {
        $self->{REV_MAPPING}->{$self->{FWD_MAPPING}->{$key}} = $key;
    }
    #print "MP3_Tags FWD_MAPPING: ", Dumper($self->{FWD_MAPPING});
    #print "MP3_Tags REV_MAPPING: ", Dumper($self->{REV_MAPPING});
    $self->{DEBUG} = 0;
    return;
}

#
# If a file has V1 but no V2, use V1 tags to create V2 tags
# If a file has V1 and also V2, use V2 tags and fill in with V1 tags (if needed)
# This ends up being: add all V1 found, then add all V2 (overwriting any V1 tags)
#
sub read_tags
{
    my $self = shift;
    my $tag_record = shift;
    my $line;
    my $current_tag;
    my $retval = 0;
    my $dbg = 0;

    return $retval if !$self->query('is_ok');

    # There is some kind of bad interaction between Encode and
    # XML::Simple when there is a broken XML::SAX on the system. See
    # the README file for XML::Simple for more about XML::SAX. The
    # badness causes the first decode of UTF-16 to be bad. This seems
    # to fix it...
    my $found = Encode::decode('UTF-16', pack("H*", "fffe47007200"));

    my $exact_tags = $self->{EXACT_TAGS};

    my $filename = $tag_record->get_value('FILE');
    #print "MP3_Tag: filename is \"$filename\"\n";
    #if ($filename eq q{/home/big/Music/mm/Hip-Hop Classics/Music/Nice and Smooth - Funky for you.mp3})
    #{
    #  $dbg = 1;
    #}

    if (!exists $self->{ID3_ENCODING_TYPE})
    {
        $self->{ID3_ENCODING_TYPE} = Idval::Common::get_common_object('id3_encoding') eq 'iso-8859-1' ? 0 : 1;
    }

    my $mp3 = MP3::Tag->new($filename);

    $mp3->get_tags();
    my ($title, $track, $artist, $album, $comment, $year, $genre);

    if (exists $mp3->{ID3v1})
    {
        #print STDERR "MP3: Yes to ID3v1\n";
        ($title, $artist, $album, $year, $comment, $track, $genre) = $mp3->{ID3v1}->all;

        $tag_record->add_tag($self->{FWD_MAPPING}->{'TITLE'}, $title);
        $tag_record->add_tag($self->{FWD_MAPPING}->{'TRACK'}, $track);
        $tag_record->add_tag($self->{FWD_MAPPING}->{'ARTIST'}, $artist);
        $tag_record->add_tag($self->{FWD_MAPPING}->{'ALBUM'}, $album);
        $tag_record->add_tag($self->{FWD_MAPPING}->{'COMMENT'}, $comment);
        $tag_record->add_tag($self->{FWD_MAPPING}->{'YEAR'}, $year);
        $tag_record->add_tag($self->{FWD_MAPPING}->{'GENRE'}, $genre);
    }

    my $frameIDs_hash = {};

    #print STDERR "\nMP3: File \"$filename\"\n";
    if (exists $mp3->{ID3v2})
    {
        #print STDERR "MP3: Yes to ID3v2 2 2 2 2\n";
        if (!exists($self->{SUPPORTED_TAGS}))
        {
            $self->{SUPPORTED_TAGS} = $mp3->{ID3v2}->supported_frames();
        }

        $frameIDs_hash = $mp3->{ID3v2}->get_frame_ids('truename');
        my $valstr = '';

        foreach my $frame (keys %$frameIDs_hash)
        {
            print ">>> $frame:\n" if $dbg;

            if (!exists($self->{SUPPORTED_TAGS}->{$frame}))
            {
                print "\"$frame\" not supported.\n" if $dbg;
                next;
            }

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
                print "<<<<GOT AN ARRAY>>>\n" if $dbg and scalar @rest;
                # Some language descriptors have NULs. Don't like.
                if ((exists $self->{HAS_LANGUAGE_DESC}->{$frame}) && ($$info_item[1] eq "\x{0}\x{0}\x{0}") &&(!$exact_tags) )
                {
                    $$info_item[1] = 'XXX';
                }

                if ($frame eq 'PIC' or $frame eq 'APIC')
                {
                    print "Got $frame, bad idea to look too closely...\n" if $dbg;
                }
                else
                {
                    print "Frame $frame, info_item: ", Dumper($info_item) if $dbg;
                    print "Frame $frame, rest: ", Dumper(\@rest) if $dbg;
                }
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
                            if ($frame eq 'PIC' or $frame eq 'APIC')
                            {
                                print "Got $frame, bad idea to look too closely...\n" if $dbg;
                            }
                            else
                            {
                                print "MP3_Tag: info for frame \"$frame\" is: ", Dumper($info) if $dbg;
                            }
                            if ($frame eq 'TXXX' and $$info[1] =~ m/^idv-(.*)/)
                            {
                                # This was a tag that was wrapped into a TXXX tag.
                                # Unwrap it here and store it in the record.
                                $tag_record->add_tag($1, $$info[2]);
                                next;
                            }
                            elsif ($frame eq 'GEOB' or
                                   $frame eq 'PRIV' or
                                   $frame eq 'APIC' or
                                   $frame eq 'NCON' or
                                   $frame eq 'PIC'
                                  )
                            {
                                $valstr = '%placeholder%';
                            }
                            elsif ($frame =~ $self->{IS_ENCODABLE_REGEXP})
                            {
                                print "MP3_Tag: Got encodable match for $frame\n" if $dbg;
                                my $encoding = shift(@{$info});
                                # Only keep the encoding if it's different from the default
                                print "MP3_Tag: encoding is \"$encoding\" type is \"", $self->{ID3_ENCODING_TYPE}, "\"\n" if $dbg;
                                $valstr = '';
                                if ($encoding ne $self->{ID3_ENCODING_TYPE})
                                {
                                    $valstr = $encoding . $self->{VISIBLE_SEPARATOR};
                                }
                                print "MP3_Tag: 1 valstr is \"$valstr\"\n" if $dbg;
                                $valstr .= join($self->{VISIBLE_SEPARATOR}, @{$info});
                                # Sometimes, NULs will be in the tag
                                $valstr =~ s/\x{0}//g unless $exact_tags;
                                print "MP3_Tag: 2 valstr is \"$valstr\"\n" if $dbg;
                            }
                            else
                            {
                                $valstr = join($self->{VISIBLE_SEPARATOR}, @{$info});
                                # Sometimes, NULs will be in the tag
                                $valstr =~ s/\x{0}//g unless $exact_tags;
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
                        print "Frame $frame, valstr: \"$valstr\"\n" if $dbg;
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

    my $dbg = 1;
    my $vs = $self->{VISIBLE_SEPARATOR};
    my $filename = $tag_record->get_name();

    if (!exists $self->{ID3_ENCODING_TYPE})
    {
        $self->{ID3_ENCODING_TYPE} = Idval::Common::get_common_object('id3_encoding') eq 'iso-8859-1' ? 0 : 1;
    }

    my $temp_rec = Idval::Record->new({Record=>$tag_record});

    my $write_id3v1_tags = $self->{CONFIG}->get_single_value('write_id3v1_tags', $temp_rec, 1);

    my $mp3 = MP3::Tag->new($filename);
    $mp3->get_tags();

    my $has_id3v1 = 0;
    my %id3v1_tags;

    #print "MP3_Tag, processing \"$filename\"\n";

    if ($write_id3v1_tags)
    {
        my $tag;
        my $id3v1_subr;

        my $id3v1 = exists($mp3->{ID3v1}) ? $mp3->{ID3v1} : $mp3->new_tag("ID3v1");

        foreach my $id3v1_key (qw(TITLE TRACK ARTIST ALBUM COMMENT YEAR GENRE))
        {
            # The information is stored as a id3v2 tag, so get the corresponding id3v2 tag name
            $tag = $self->{FWD_MAPPING}->{$id3v1_key};

            $id3v1_subr = lc $id3v1_key;

            # A bit of trickiness; the id3v1 object uses method accessors with the same name
            # as the ID3v1 tag.
            # Don't use Idval::Record::shift_value(), because we want to always write out the id3v2 tag
            $id3v1->$id3v1_subr($temp_rec->get_first_value($tag));
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
    #print "ID3v2:", Dumper($id3v2);

  TAG_LOOP:
    foreach my $tagname ($temp_rec->get_all_keys())
    {
        print "Checking \"$tagname\"\n" if $dbg;
        $tag_index = -1;
        while ($tagvalue = $temp_rec->shift_value($tagname))
        {
            #confess("Undefined value for tag \"$tagname\"") unless defined($tagvalue);
            $tag_index++;
            $framename = $tag_index > 0 ? sprintf("%s%02d", $tagname, $tag_index) : $tagname;

            print "Tag name is \"$tagname\"\n" if $dbg;
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

                print "tagvalue: \"$tagvalue\" vs: \"$vs\" is_decodable: ", $self->{IS_ENCODABLE_REGEXP}, " id3_enc: ", $self->{ID3_ENCODING_TYPE}, "\n";
                @frameargs = ($tagvalue =~ m/\Q$vs\E/)                       ? split(/\Q$vs\E/, $tagvalue)
                           # There may be a default, implicit, encoding. If so, add it back in.
                           : ($tagname =~ $self->{IS_ENCODABLE_REGEXP})      ? split(/\Q$vs\E/, $self->{ID3_ENCODING_TYPE} . $vs . $tagvalue)
                           : ($tagvalue);
                print "Args for $framename are ", Dumper(\@frameargs) if $dbg;
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
                print "Tag $framename exists in file\n" if $dbg;
                $id3v2->change_frame($framename, @frameargs);
            }
            else
            {
                print "Tag $framename does not exist in file\n" if $dbg;
                $id3v2->add_frame($framename, @frameargs);
            }
        }
    }

    # Handle the leftover tags (they were in the file, but not in the tag record, so they should be deleted)
    foreach my $frameID (keys %{$frameIDs})
    {
        print "Removing $frameID\n" if $dbg;
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

    # XXX MP3::Tag is filling in id3v1 tags....
    $id3v2->write_tag();
    # Now, we should be left with all the tags that weren't ID3v1 or ID3v2 (shouldn't be any)

    print STDERR "MP3: Tags left: ", join(":", $temp_rec->format_record()), "\n";

    return 0;
}

sub close
{
    my $self = shift;

    delete $self->{ID3_ENCODING_TYPE} if exists $self->{ID3_ENCODING_TYPE};
}

1;
