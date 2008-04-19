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

our $name = 'id3v2';
our $type = 'MP3';
our %xlat_tags = 
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
}

sub read_tags
{
    my $self = shift;
    my $record = shift;
    my $line;
    my $current_tag;

    return if !$self->query('is_ok');

    my %v1tags;
    my %v2tags;
    my $filename = $record->get_value('FILE');
    my $path = $self->query('path');
    my $tag;

    $filename =~ s{/cygdrive/(.)}{$1:}; # Tag doesn't deal well with cygdrive pathnames
    foreach $line (`$path --list "$filename" 2>&1`) {
        chomp $line;
        $line =~ s/\r//;
        #print "<$line>\n";

        $line =~ m/^Title\s*:\s*(.*)\s*Artist:\s*(.*)$/ and do {
            $v1tags{TITLE} = $1;
            $v1tags{ARTIST} = $2;
            #$record->add_tag('TITLE', $1);
            #$record->add_tag('ARTIST', $2);
            next;
        };

        $line =~ m/^Album\s*:\s*(.*)\s*Year:\s*(.*),\s*Genre:\s*(\S*)\s*\(\S*\)$/ and do {
            $v1tags{ALBUM} = $1;
            $v1tags{YEAR} = $2;
            $v1tags{GENRE} = $3;
            #$record->add_tag('ALBUM', $1);
            #$record->add_tag('YEAR', $2);
            #$record->add_tag('GENRE', $3);
            next;
        };

        $line =~ m/^Comment\s*:\s*(.*)\s*Track:\s*(.*)$/ and do {
            $v1tags{COMMENT} = $1;
            $v1tags{TRACKNUMBER} = $2;
            #$record->add_tag('COMMENT', $1);
            #$record->add_tag('TRACKNUMBER', $2);
            next;
        };

        $line =~ m|^TSSE\s+\(Software/Hardware and settings used for encoding\):\s*(.*)$| and do {
            $v2tags{TSSE} = $1;
            next;
        };

        $line =~ m|^TIT2:\s*\(Title/songname/content description\):\s*(.*)$| and do {
            $v2tags{TITLE} = $1;
            next;
        };

        $line =~ m|^TPE1:\s*\(Lead performer\(s\)/Soloist\(s\)\):\s*(.*)$| and do {
            $v2tags{ARTIST} = $1;
            next;
        };

        $line =~ m|^TALB:\s*\(Album/Movie/Show title\):\s*(.*)$| and do {
            $v2tags{ALBUM} = $1;
            next;
        };

        $line =~ m|^TYER:\s*\(Year\):\s*(.*)$| and do {
            $v2tags{YEAR} = $1;
            next;
        };

        $line =~ m|^COMM:\s*\(Comments\):\s*\(.*\)\s*\[.*\]:\s*(.*)$| and do {
            $v2tags{COMMENT} = $1;
            next;
        };

        $line =~ m|^TCON:\s*\(Content type\):\s*(\S*)| and do {
            $v2tags{GENRE} = $1;
            next;
        };

        $line =~ m|^APIC:\s*\(Attached picture\)(.*)$| and do {
            $v2tags{PICTURE} = $1;
            next;
        };
    }

    if (Idval::Common::do_v1tags_only())
    {
        foreach $tag (keys %v1tags)
        {
            $record->add_tag($tag, defined($v1tags{$tag}) ? $v1tags{$tag} : '');
        }
    }
    elsif (Idval::Common::do_v2tags_only())
    {
        foreach $tag (keys %v2tags)
        {
            $record->add_tag($tag, defined($v2tags{$tag}) ? $v2tags{$tag} : '');
        }
    }
    elsif (Idval::Common::prefer_v2tags() and not %v2tags)
    {
        foreach $tag (keys %v1tags)
        {
            $record->add_tag($tag, defined($v1tags{$tag}) ? $v1tags{$tag} : '');
        }
    }
}

sub write_tags
{
    my $self = shift;
    my $record = shift;

    return 0 if !$self->query('is_ok');

    my $filename = $record->get_name();
    my $path = $self->query('path') . " ";

    Idval::Common::run($path, '--remove', $filename);

    my $status = Idval::Common::run($path,
                                    $record->get_value_as_arg('--title ', 'TITLE'),
                                    $record->get_value_as_arg('--artist ', 'ARTIST'),
                                    $record->get_value_as_arg('--album ', 'ALBUM'),
                                    $record->get_value_as_arg('--year ', 'DATE'),
                                    $record->get_value_as_arg('--comment ', 'COMMENT'),
                                    $record->get_value_as_arg('--track ', 'TRACKNUMBER'),
                                    $record->get_value_as_arg('--genre ', 'GENRE'),
                                    $filename);

    return $status;
}

2;
