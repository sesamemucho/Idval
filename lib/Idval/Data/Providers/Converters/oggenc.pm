package Idval::Plugins::Converters::OggEnc;

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
use Data::Dumper;

use base qw(Idval::Converter);

Idval::Common::register_provider({provides=>'converts', name=>'oggenc', from=>'WAV', to=>'OGG', attributes=>'transcode'});

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

    #$self->set_param('name', $self->{NAME});
    $self->set_param('filetype_map', {'WAV' => [qw{ wav }],
                                      'OGG' => [qw{ ogg }]});
    $self->set_param('classtype_map', {'MUSIC' => [qw( WAV OGG )]});

    $self->find_and_set_exe_path();

    $self->{PROVIDERS} = Idval::Common::get_common_object('providers');

    return;
}

sub convert
{
    my $self = shift;
    my $tag_record = shift;
    my $dest = shift;

    my $src = $tag_record->get_name();

    return 0 if !$self->query('is_ok');

    if (!exists($self->{WRITER}))
    {
        $self->{WRITER} = $self->{PROVIDERS}->get_provider('writes_tags', 'OGG', 'NULL');
    }

    my $path = $self->query('path');
    my $status = Idval::Common::run($path,
                                    Idval::Common::mkarglist(
                                        "--output=$dest",
                                        $src));

    if ($status == 0)
    {
        $tag_record->set_name($dest); # This is a copy, so we can play with it
        $status = $self->{WRITER}->write_tags({tag_record => $tag_record});
    }

    return $status;
}

1;
