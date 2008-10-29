package Idval::Plugins::Converters::OggDec;

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

use strict;
use warnings;
no warnings qw(redefine);
use Idval::Common;
use Class::ISA;

use base qw(Idval::Converter);

Idval::Common::register_provider({provides=>'converts', name=>'oggdec', from=>'OGG', to=>'WAV', attributes=>'transcode'});

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
    $self->set_param('filetype_map', {'WAV' => [qw{ wav }],
                                      'OGG' => [qw{ ogg }]});
    $self->set_param('classtype_map', {'MUSIC' => [qw( WAV OGG )]});

    $self->find_and_set_exe_path();

    return;
}

sub convert
{
    my $self = shift;
    my $rec = shift;
    my $dest = shift;

    my $src = $rec->get_name();

    return 0 if !$self->query('is_ok');

    my $path = $self->query('path');
    #print STDERR "OGG: $path --output=$dest $src\n";
    my $status = Idval::Common::run($path,
                                    Idval::Common::mkarglist(
                                        "--output=$dest",
                                        $src));

    return $status;
}

1;
