package Idval::Plugins::Taggers::Vorbiscomment;

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

use Idval::Logger qw(nchatty nidv_warn debug);
use base qw(Idval::Provider);

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

    # Forward mapping is OGG to ID3v2
    # Reverse mapping is ID3v2 to OGG
    $self->get_tagname_mappings(Idval::Common::get_common_object('config'),
                                'OGG');

    return;
}

sub read_tags
{
    my $self = shift;
    my $tag_record = shift;
    my $line;
    my $current_tag;
    my $tag_value;
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
            nidv_warn('Getters::BadVorbis', $line, $filename, "\n");
            nchatty("ref record: ", ref $tag_record, "\n");
            $retval = 1;
            last;
        }

        if ($line =~ m/^(\S+)\s*=\s*(.*)/)
        {
            $current_tag = uc($1);
            $tag_value = $2;
            if (exists($self->{FWD_MAPPING}->{$current_tag}))
            {
                $tag_record->add_tag($self->{FWD_MAPPING}->{$current_tag}, $tag_value);
            }
            next;
        }

        $tag_record->add_to_tag($current_tag, "\n$line");
    }

    #debug("\nGot tag:\n");
    #debug(join("\n", $tag_record->format_record()));

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
    my $vorbisname;
    foreach my $tagname ($tag_record->get_all_keys())
    {
        if(exists($self->{REV_MAPPING}->{$tagname}))
        {
            $vorbisname = $self->{REV_MAPPING}->{$tagname};
            push(@taglist, $tag_record->get_value_as_arg('-t ' . $vorbisname . '=', $tagname));
        }
    }

    my $status = Idval::Common::run($path,
                                    Idval::Common::mkarglist(
                                    '-w',
                                        @taglist,
                                        $filename));

    return $status;
}

1;
