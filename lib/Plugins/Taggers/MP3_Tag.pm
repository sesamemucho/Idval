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
    my ($title, $track, $artist, $album, $comment, $year, $genre);

    if ($self->{MELD_MP3_TAGS})
    {
        ($title, $track, $artist, $album, $comment, $year, $genre) = $mp3->autoinfo();
    }
    else
    {
        if (exists $mp3->{ID3v1})
        {
            ($title, $artist, $album, $year, $comment, $track, $genre) = $mp3->{ID3v1}->all;
            $tag_record->add_tag('TITLE', $title);
            $tag_record->add_tag('TRACKNUMBER', $track);
            $tag_record->add_tag('ARTIST', $artist);
            $tag_record->add_tag('ALBUM', $album);
            $tag_record->add_tag('COMMENT', $comment);
            $tag_record->add_tag('DATE', $year);
            $tag_record->add_tag('GENRE', $genre);
        }
    }


    my $frameIDs_hash = {};

    if (exists $mp3->{ID3v2})
    {
        $frameIDs_hash = $mp3->{ID3v2}->get_frame_ids('truename');
        my $valstr = '';

        foreach my $frame (keys %$frameIDs_hash)
        {
            #print ">>> $frame:\n";
            next if $frame eq 'GEOB';
            next if $frame eq 'PRIV';
            next if $frame eq 'APIC';
            next if $frame eq 'NCON';
            my ($info_item, $name, @rest) = $mp3->{ID3v2}->get_frame($frame);
            next unless defined($name); # Unrecognized format
            #print "<<<<GOT AN ARRAY>>>\n" if scalar @rest;
            my @tagvalues = ();
            for my $info ($info_item, @rest)
            {
                if (ref $info)
                {
                    #print "$name ($frame):\n";
                    my @vals = ();
                    while(my ($key,$val)=each %$info)
                    {
                        #print " * $key => $val\n";
                        push(@vals, $val);
                    }
                    $valstr = join($self->{VISIBLE_SEPARATOR}, @vals);
                }
                else
                {
                    #print "$name: $info\n";
                    $valstr = $info;
                }

                push(@tagvalues, $valstr);
            }
            if (scalar(@tagvalues) > 1)
            {
                print "<<< Got an array for file $filename, frame $frame\n";
            }
            $tag_record->add_tag($frame, scalar @tagvalues == 1 ? \@tagvalues : $tagvalues[0]);
        }
    }

    $frameIDs_hash->{'TIT2'} = $title   if ($title   && !exists($frameIDs_hash->{'TIT2'}));
    $frameIDs_hash->{'TPE1'} = $artist  if ($artist  && !exists($frameIDs_hash->{'TPE1'}));
    $frameIDs_hash->{'TALB'} = $album   if ($album   && !exists($frameIDs_hash->{'TALB'}));
    $frameIDs_hash->{'TYER'} = $year    if ($year    && !exists($frameIDs_hash->{'TYER'}));
    $frameIDs_hash->{'COMM'} = $comment if ($comment && !exists($frameIDs_hash->{'COMM'}));
    $frameIDs_hash->{'TRCK'} = $track   if ($track   && !exists($frameIDs_hash->{'TRCK'}));
    $frameIDs_hash->{'TCON'} = $genre   if ($genre   && !exists($frameIDs_hash->{'TCON'}));


    return $retval;
}

1;
