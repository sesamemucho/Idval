package Idval::SysPlugins::Converters::Flac;

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

my $name = 'flac';

Idval::Common::register_provider({provides=>'converts', name=>'flac_enc', from=>'WAV', to=>'FLAC', attributes=>'transcode'});
Idval::Common::register_provider({provides=>'converts', name=>'flac_encogg', from=>'OGG', to=>'FLAC', attributes=>'transcode'});
Idval::Common::register_provider({provides=>'converts', name=>'flac_dec', from=>'FLAC', to=>'WAV', attributes=>'transcode'});

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
                                      'FLAC' => [qw{ flac flac16 flac24}]});
    $self->set_param('classtype_map', {'MUSIC' => [qw( WAV FLAC )]});
    # Since we have a choice, tell the typemapper that we want our
    # output files to have a '.flac' extension
    $self->set_param('output_ext_map', {'FLAC' => [qw( flac )]});

    $self->find_and_set_exe_path('flac');

    return;
}

sub convert
{
    my $self = shift;
    my $tag_record = shift;
    my $dest = shift;

    return 0 if !$self->query('is_ok');

    my $name = $self->{NAME};

    my $src = $tag_record->get_name();

    $dest = Idval::Common::mung_path($dest);
    $src = Idval::Common::mung_path($src);

    my $path = $self->query('path') . " ";

    if ($name eq 'flac_dec')
    {
        return $self->decode($tag_record, $dest, $src, $path);
    }
    else
    {
        return $self->encode($tag_record, $dest, $src, $path);
    }
}

sub decode
{
    my $self = shift;
    my $tag_record = shift;
    my $dest = shift;
    my $src = shift;
    my $path = shift;

    my $extra_args = $self->{CONFIG}->get_single_value('extra_args', {'command_name' => 'flac_dec'});

    my $status = Idval::Common::run($path,
                                    Idval::Common::mkarglist(
                                        $extra_args,
                                        #"--silent",
                                        "--decode",
                                        -o "$dest",
                                        $src));

    return $status;
}

sub encode
{
    my $self = shift;
    my $tag_record = shift;
    my $dest = shift;
    my $src = shift;
    my $path = shift;

    my $extra_args = $self->{CONFIG}->get_single_value('extra_args', {'command_name' => $self->{NAME}});

    my @tags;
    foreach my $tagname ($tag_record->get_all_keys())
    {
        push(@tags, $tag_record->get_value_as_arg("--tag=$tagname=", $tagname));
    }

    my $status = Idval::Common::run($path,
                                    Idval::Common::mkarglist(
                                        $extra_args,
                                        "-o",
                                        "$dest",
                                        @tags,
                                        $src));

    return $status;
}

1;
