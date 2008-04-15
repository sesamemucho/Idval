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

use Idval::Setup;
use Class::ISA;

use base qw(Idval::Converter);

our $name = 'lame';
#our $from = 'WAV';
#our $to = 'MP3';

#Idval::Common::register_provider({provides=>'converts', name=>$name, from=>$from, to=>$to});
Idval::Common::register_provider({provides=>'converts', name=>'lame_enc', from=>'WAV', to=>'MP3'});
Idval::Common::register_provider({provides=>'converts', name=>'lame_dec', from=>'MP3', to=>'WAV'});

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

    if ($name eq 'lame_dec')
    {
        $self->set_param('from', 'MP3');
        $self->set_param('to', 'WAV');
    }
    else
    {
        $self->set_param('from', 'WAV');
        $self->set_param('to', 'MP3');
    }

    my $path = $self->find_exe_path('lame');
    $self->set_param('path', $path);
    $self->set_param('is_ok', defined($path));
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
    my $record = shift;
    my $dest = shift;

    my $src = $record->get_name();

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
    my $record = shift;
    my $dest = shift;

    my $src = $record->get_name();

    return 0 if !$self->query('is_ok');

    $dest = Idval::Common::mung_path($dest);
    $src = Idval::Common::mung_path($src);

    my $path = $self->query('path') . " ";
    #print STDERR "LAME: $path --output=$dest $src\n";
    my $status = Idval::Common::run($path,
                                    Idval::Common::mkarglist(
                                        "--quiet",
                                        $record->get_value_as_arg('--tt ', 'TITLE'),
                                        $record->get_value_as_arg('--ta ', 'ARTIST'),
                                        $record->get_value_as_arg('--tl ', 'ALBUM'),
                                        $record->get_value_as_arg('--ty ', 'DATE'),
                                        $record->get_value_as_arg('--tc ', 'COMMENT'),
                                        $record->get_value_as_arg('--tn ', 'TRACKNUMBER'),
                                        $record->get_value_as_arg('--tg ', 'GENRE'),
                                        $src,
                                        $dest));

    return $status;
}

1;
