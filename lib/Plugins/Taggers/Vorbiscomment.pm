package Idval::SysPlugins::Vorbiscomment;

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

my $name = 'vorbiscomment';
my $type = 'OGG';

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
    $self->set_param('Goober', $self->{NAME});
    $self->set_param('dot_map', {'OGG' => [qw{ o }]});
    $self->set_param('filetype_map', {'OGG' => [qw{ ogg }]});
    $self->set_param('classtype_map', {'MUSIC' => [qw( OGG )]});
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

    return 0 if !$self->query('is_ok');

    my $filename = $tag_record->get_value('FILE');
    my $path = $self->query('path');

    #$filename =~ s{/cygdrive/(.)}{$1:}; # Tag doesn't deal well with cygdrive pathnames
    foreach my $line (`$path -l "$filename" 2>&1`) {
        chomp $line;
        $line =~ s/\r//;
        #print "<$line>\n";

        next if $line =~ /^\s*$/;

        if ($line =~ m/Failed to open file as vorbis/)
        {
            print 'Getters::BadVorbis', $line, $filename, "\n";
            print "ref record: ", ref $tag_record, "\n";
            $retval = 1;
            last;
        }

        if ($line =~ m/^(\S+)\s*=\s*(.*)/)
        {
            $current_tag = uc($1);
            $tag_record->add_tag($current_tag, $2);
            next;
        }

        $tag_record->add_to_tag($current_tag, "\n$line");
    }

    #print "\nGot tag:\n";
    #print join("\n", $tag_record->format_record());

    $tag_record->commit_tags();

    return $retval;
}

sub write_tags
{
    my $self = shift;
    my $tag_record = shift;

    return 0 if !$self->query('is_ok');

    my $filename = $tag_record->get_value('FILE');
    my $path = $self->query('path');

    my @taglist;
    foreach my $tagname ($tag_record->get_all_keys())
    {
        push(@taglist, $tag_record->get_value_as_arg('-t ' . $tagname . '=', $tagname));
    }

    my $status = Idval::Common::run($path,
                                    '-w',
                                    @taglist,
                                    $filename);

    return $status;
}

1;
