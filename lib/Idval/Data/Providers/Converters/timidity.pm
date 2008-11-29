package Idval::Plugins::Converters::Timidity;

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

use base qw(Idval::Converter);

my $name = 'timidity';

Idval::Common::register_provider({provides=>'converts', name=>'timidity', from=>'MIDI', to=>'WAV', attributes=>'transcode'});

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
    $self->set_param('filetype_map', {'MIDI' => [qw{ mid midi}],
                                      'WAV' => [qw{ wav }]});
    $self->set_param('classtype_map', {'MUSIC' => [qw( MIDI WAV )]});
    # Since we have a choice, tell the typemapper that we want our
    # output files to have a '.flac' extension
    $self->set_param('output_ext_map', {'WAV' => [qw( wav )]});

    my $config = Idval::Common::get_common_object('config');
    #$self->{VISIBLE_SEPARATOR} = $config->get_single_value('visible_separator', {'config_group' => 'idval_settings'});

    $self->find_and_set_exe_path('timidity');

    my $cfg_file = $self->{CONFIG}->get_single_value('config_file', {'command_name' => 'timidity'});
    $cfg_file = Idval::Common::mung_path($cfg_file);
    my @cfg_args = $cfg_file ? ('-c', "$cfg_file") : ();
    $self->{CFG_ARGS} = \@cfg_args;

    return;
}

sub convert
{
    my $self = shift;
    my $tag_record = shift;
    my $dest = shift;

    return 0 if !$self->query('is_ok');

    my $timidity_args = $self->{CONFIG}->get_single_value('timidity_args', $tag_record);
    my @timidity_args_list = split(' ', $timidity_args);

    my $src = $self->get_source_filepath($tag_record);
    $dest = Idval::Common::mung_path($dest);
    $src = Idval::Common::mung_path($src);

    my $path = $self->query('path');
    my $status = Idval::Common::run($path,
                                    Idval::Common::mkarglist(
                                        @{$self->{CFG_ARGS}},
                                        '-Ow',
                                        $timidity_args,
                                        '-o', "$dest",
                                        "$src"));


    return $status;
}

1;
