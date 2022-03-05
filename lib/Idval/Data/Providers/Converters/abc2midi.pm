package Idval::Plugins::Converters::Abc2midi;

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
use Idval::I18N;
use Idval::Common;
use Class::ISA;

use base qw(Idval::Converter);

my $name = 'abc2midi';

Idval::Common::register_provider({provides=>'converts', name=>'abc2midi', from=>'ABC', to=>'MIDI', attributes=>'transcode'});

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
    $self->set_param('filetype_map', {'ABC' => [qw{ abc }],
                                      'MIDI' => [qw{ mid midi}]});
    $self->set_param('classtype_map', {'MUSIC' => [qw( ABC MIDI )]});
    # Since we have a choice, tell the typemapper that we want our
    # output files to have a '.flac' extension
    $self->set_param('output_ext_map', {'MIDI' => [qw( mid )]});

    my $config = Idval::Common::get_common_object('config');
    $self->{VISIBLE_SEPARATOR} = $config->i18n_get_single_value('config', 'visible_separator', {'config_group' => 'idval_settings'});

    $self->{LH} = Idval::I18N->idv_get_handle() || die "Can't get language handle.";
    $self->find_and_set_exe_path('abc2midi');

    return;
}

sub convert
{
    my $self = shift;
    my $tag_record = shift;
    my $dest = shift;

    return 0 if !$self->query('is_ok');

    my $extra_args = $self->{CONFIG}->i18n_get_single_value('config', 'extra_args', {'command_name' => 'abc2midi'});

    my $src = $self->get_source_filepath($tag_record);
    $dest = Idval::Common::mung_path($dest);
    $src = Idval::Common::mung_path($src);

    my $ref_num = $tag_record->get_value('TRCK');
    my $path = $self->query('path');
    my $status = Idval::Common::run($path,
                                    Idval::Common::mkarglist(
                                        $src,
                                        $ref_num,
                                        $extra_args,
                                        "-o", "$dest"));

    return $status;
}

sub get_source_filepath
{
    my $self = shift;
    my $rec = shift;

    my $vs = $self->{VISIBLE_SEPARATOR};

    my ($fname, $id) = ($rec->get_name() =~ m/^(.*)\Q$vs\E(\d+)/);
 
    return $fname;
}

sub get_dest_filename
{
    my $self = shift;
    my $rec = shift;
    my $dest_name = shift;
    my $dest_ext = shift;
    my $title = $rec->get_first_value('TIT2') ||
        $self->{LH}->maketext("No \"TIT2\" tag in record for: \"[_1]\"", $rec->get_name());

    $dest_name = $rec->get_first_value('TIT2') . '.' . $dest_ext;

    return $dest_name;

}

1;
