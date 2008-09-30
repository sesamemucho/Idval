package Idval::SysPlugins::Lame;

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
use Class::ISA;

use base qw(Idval::Converter);

Idval::Common::register_provider({provides=>'converts', name=>'lame_enc', from=>'WAV', to=>'MP3', attributes=>'transcode'});
Idval::Common::register_provider({provides=>'converts', name=>'lame_dec', from=>'MP3', to=>'WAV', attributes=>'transcode'});

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
    my $name = $self->{NAME};

    $self->set_param('name', $name);
    $self->set_param('filetype_map', {'WAV' => [qw{ wav }],
                                      'MP3' => [qw{ mp3 }]});
    $self->set_param('classtype_map', {'MUSIC' => [qw( WAV MP3 )]});

    $self->find_and_set_exe_path('lame');

    $self->{PROVIDERS} = Idval::Common::get_common_object('providers');

    return;
}

sub convert
{
    my $self = shift;
    my $name = $self->{NAME};

    if ($name eq 'lame_dec')
    {
        return $self->decode(@_);
    }
    else
    {
        return $self->encode(@_);
    }
}

sub decode
{
    my $self = shift;
    my $tag_record = shift;
    my $dest = shift;

    my $src = $tag_record->get_name();

    return 0 if !$self->query('is_ok');

    $dest = Idval::Common::mung_path($dest);
    $src = Idval::Common::mung_path($src);

    my $path = $self->query('path') . " ";
    #print STDERR "OGG: $path --output=$dest $src\n";
    my $status = Idval::Common::run($path,
                                    Idval::Common::mkarglist(
                                        #"--quiet",
                                        "--decode",
                                        $src,
                                        $dest));

    return $status;
}

sub encode
{
    my $self = shift;
    my $tag_record = shift;
    my $dest = shift;

    my $src = $tag_record->get_name();

    return 0 if !$self->query('is_ok');

    if (!exists($self->{WRITER}))
    {
        $self->{WRITER} = $self->{PROVIDERS}->get_provider('writes_tags', 'MP3', 'NULL');
    }

    $dest = Idval::Common::mung_path($dest);
    $src = Idval::Common::mung_path($src);

    my $path = $self->query('path') . " ";
    #print STDERR "LAME: $path --output=$dest $src\n";
#     my $status = Idval::Common::run($path,
#                                     Idval::Common::mkarglist(
#                                         "--quiet",
#                                         "--add-id3v2",
#                                         "--ignore-tag-errors",
#                                         $tag_record->get_value_as_arg('--tt ', 'TITLE'),
#                                         $tag_record->get_value_as_arg('--ta ', 'ARTIST'),
#                                         $tag_record->get_value_as_arg('--tl ', 'ALBUM'),
#                                         $tag_record->get_value_as_arg('--ty ', 'YEAR'),
#                                         $tag_record->get_value_as_arg('--tc ', 'COMMENT'),
#                                         $tag_record->get_value_as_arg('--tn ', 'TRACK'),
#                                         $tag_record->get_value_as_arg('--tg ', 'GENRE'),
#                                         $src,
#                                         $dest));

    my $status = Idval::Common::run($path,
                                    Idval::Common::mkarglist(
                                        "--quiet",
                                        $src,
                                        $dest));


    if ($status == 0)
    {
        $status = $self->{WRITER}->writes_tags($tag_record);
    }

    return $status;
}

1;
