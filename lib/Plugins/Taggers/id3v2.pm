package Idval::SysPlugins::Id3v2;

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
no warnings qw(redefine);
use Idval::Common;
use Class::ISA;

use base qw(Idval::Plugin);

my $name = 'id3v2';
my $type = 'MP3';
my %xlat_tags = 
    ( TIME => 'DATE',
      YEAR => 'DATE',
      NAME => 'TITLE',
      TRACK => 'TRACKNUMBER',
      TRACKNUM => 'TRACKNUMBER'
    );

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
    $self->set_param('dot_map', {'MP3' => [qw{ m }]});
    $self->set_param('filetype_map', {'MP3' => [qw{ mp3 }]});
    $self->set_param('classtype_map', {'MUSIC' => [qw( MP3 )]});
    $self->set_param('type', $type);

    $self->find_and_set_exe_path();

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

    my %v1tags;
    my %v2tags;
    my $filename = $tag_record->get_value('FILE');
    my $path = $self->query('path');
    my $tag;

    $filename =~ s{/cygdrive/(.)}{$1:}; # Tag doesn't deal well with cygdrive pathnames
    foreach my $line (`$path --list "$filename" 2>&1`) {
        chomp $line;
        $line =~ s/\r//;
        #print "<$line>\n";

        if ($line =~ m/^Title\s*:\s*(.*)\s*Artist:\s*(.*)$/)
        {
            $tag_record->add_tag('TITLE', $1);
            $tag_record->add_tag('ARTIST', $2);
            next;
        };

        my $album_id = 'Album\s*:\s*';
        my $year_id = 'Year:\s*';
        my $genre_id = 'Genre:\s*';
        if ($line =~ m/^$album_id(.*)\s*$year_id(.*),\s*$genre_id(\S*)\s*\(\S*\)$/)
        {
            $tag_record->add_tag('ALBUM', $1);
            $tag_record->add_tag('YEAR', $2);
            $tag_record->add_tag('GENRE', $3);
            next;
        };

        if ($line =~ m/^Comment\s*:\s*(.*)\s*Track:\s*(.*)$/)
        {
            $tag_record->add_tag('COMMENT', $1);
            $tag_record->add_tag('TRACKNUMBER', $2);
            next;
        };

        my $tsse_comment = '\(Software/Hardware and settings used for encoding\)';
        if ($line =~ m|^TSSE\s+$tsse_comment:\s*(.*)$|)
        {
            $tag_record->add_tag(TSSE, $1);
            next;
        };

        if ($line =~ m|^TIT2:\s*\(Title/songname/content description\):\s*(.*)$|)
        {
            $tag_record->add_tag(TITLE, $1);
            next;
        };

        if ($line =~ m|^TPE1:\s*\(Lead performer\(s\)/Soloist\(s\)\):\s*(.*)$|)
        {
            $tag_record->add_tag(ARTIST, $1);
            next;
        };

        if ($line =~ m|^TALB:\s*\(Album/Movie/Show title\):\s*(.*)$|)
        {
            $tag_record->add_tag(ALBUM, $1);
            next;
        };

        if ($line =~ m|^TYER:\s*\(Year\):\s*(.*)$|)
        {
            $tag_record->add_tag(YEAR, $1);
            next;
        };

        if ($line =~ m|^COMM:\s*\(Comments\):\s*\(.*\)\s*\[.*\]:\s*(.*)$|)
        {
            $tag_record->add_tag(COMMENT, $1);
            next;
        };

        if ($line =~ m|^TCON:\s*\(Content type\):\s*(\S*)|)
        {
            $tag_record->add_tag(GENRE, $1);
            next;
        };

        if ($line =~ m|^APIC:\s*\(Attached picture\)(.*)$|)
        {
            $tag_record->add_tag(PICTURE, $1);
            next;
        };
    }

    $tag_record->commit_tags();

    return $retval;
}

sub write_tags
{
    my $self = shift;
    my $tag_record = shift;

    return 0 if !$self->query('is_ok');

    my $filename = $tag_record->get_name();
    my $path = $self->query('path') . " ";

    Idval::Common::run($path, '--remove', $filename);

    my $status = Idval::Common::run($path,
                                    $tag_record->get_value_as_arg('--title ', 'TITLE'),
                                    $tag_record->get_value_as_arg('--artist ', 'ARTIST'),
                                    $tag_record->get_value_as_arg('--album ', 'ALBUM'),
                                    $tag_record->get_value_as_arg('--year ', 'DATE'),
                                    $tag_record->get_value_as_arg('--comment ', 'COMMENT'),
                                    $tag_record->get_value_as_arg('--track ', 'TRACKNUMBER'),
                                    $tag_record->get_value_as_arg('--genre ', 'GENRE'),
                                    $filename);

    return $status;
}

1;
