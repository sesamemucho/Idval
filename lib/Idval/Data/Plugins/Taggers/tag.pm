package Idval::SysPlugins::Tag;

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
use Idval::Common;
use Class::ISA;

use base qw(Idval::Plugin);

my $name = 'tag';
my $type = 'MP3';
my %xlat_tags = 
    ( TIME => 'DATE',
      YEAR => 'DATE',
      NAME => 'TITLE',
      TRACK => 'TRACKNUMBER',
      TRACKNUM => 'TRACKNUMBER'
    );

my %c2v1 = 
    ( DATE => 'TIME',
      DATE => 'YEAR',
      TITLE => 'NAME',
      TRACKNUMBER => 'TRACKNUM'
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

    my $filename = $tag_record->get_value('FILE');
    my $path = $self->query('path');

    $filename =~ s{/cygdrive/(.)}{$1:}; # Tag doesn't deal well with cygdrive pathnames
    #print "Tag checking \"$filename\"\n";
    foreach my $line (`$path --hideinfo --hidenames "$filename" 2>&1`) {
        chomp $line;
        $line =~ s/\r//;
        #print "<$line>\n";

        next if $line =~ /^Tag /;
        next if $line =~ /^Copyright /;
        next if $line =~ /^Version /;
        next if $line =~ /^\s*$/;

        if ($line =~ m/^File has no known tags./)
        {
            $retval = 1;
            last;
        };

        # All MP3 tag names should be upper-case
        if ($line =~ m/^(\S+):\s*(.*)/)
        {
            $current_tag = uc($1);
            $current_tag = $xlat_tags{$current_tag} if exists $xlat_tags{$current_tag};
            $tag_record->add_tag($current_tag, $2);
            next;
        };

        if ($line =~ m/^(\S+)\s*=\s*(.*)/)
        {
            $current_tag = uc($1);
            $current_tag = $xlat_tags{$current_tag} if exists $xlat_tags{$current_tag};
            $tag_record->add_tag($current_tag, $2);
            next;
        };

        $tag_record->add_to_tag($current_tag, "$line");
    }

    return $retval;
}

sub write_tags
{
    my $self = shift;
    my $tag_record = shift;

    return 0 if !$self->query('is_ok');

    my $filename = $tag_record->get_name();
    my $path = $self->query('path') . " ";

    $filename =~ s{/cygdrive/(.)}{$1:}; # Tag doesn't deal well with cygdrive pathnames
    Idval::Common::run($path, '--remove', $filename);

    my $status = Idval::Common::run($path,
                                    $tag_record->get_value_as_arg('--title ', 'TITLE', $c2v1{'TITLE'}),
                                    $tag_record->get_value_as_arg('--artist ', 'ARTIST', $c2v1{'ARTIST'}),
                                    $tag_record->get_value_as_arg('--album ', 'ALBUM', $c2v1{'ALBUM'}),
                                    $tag_record->get_value_as_arg('--year ', 'DATE', $c2v1{'DATE'}),
                                    $tag_record->get_value_as_arg('--comment ', 'COMMENT', $c2v1{'COMMENT'}),
                                    $tag_record->get_value_as_arg('--track ', 'TRACKNUMBER', $c2v1{'TRACKNUMBER'}),
                                    $tag_record->get_value_as_arg('--genre ', 'GENRE', $c2v1{'GENRE'}),
                                    $filename);

    return $status;
}

1;
