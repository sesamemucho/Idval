package Idval::SysPlugins::Copy;

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

my $name = 'copy';
#our $from = 'WAV';
#our $to = 'MP3';

#Idval::Common::register_provider({provides=>'converts', name=>$name, from=>$from, to=>$to});
Idval::Common::register_provider({provides=>'converts', name=>'copy', from=>'WAV', to=>'WAV'});

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

    $self->set_param('is_ok', 1);
    return;
}

sub convert
{
    my $self = shift;
    my $tag_record = shift;
    my $dest = shift;


    print STDERR "Copying to \"$dest\"\n";

    return 1;
}

1;
