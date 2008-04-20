package Idval::SysPlugins::Abc;

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

use base qw(Idval::Converter);

Idval::Common::register_provider({provides=>'converts', name=>'abc_enc', from=>'ABC', to=>'MIDI'});

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

    $self->set_param('path', 'not yet');
    #$self->set_param('is_ok', defined($path));
    $self->set_param('is_ok', 0);
    $self->set_param('status', 'not implemented');
}

#
# For .abc files, record name will be like file_name_maybe with
# strange chars%%tune title where '%%' is a separator. There will
# probably need to be escaping. Don't forget about Unicode.
#
sub get_source_filepath
{
    my $self = shift;
    my $rec = shift;
    my ($src, $title) = ($rec->get_name() =~ m{^(.*)(.*)$});

    return $src;
}

sub get_dest_filename
{
    my $self = shift;
    my $rec = shift;
    my $dest_name = shift;
    my $dest_ext = shift;

    my ($src, $title) = ($rec->get_name() =~ m{^(.*)(.*)$});

    $title =~ s{\.[^.]+$}{};
    $title .= ".$dest_ext";

    return $title;
}

sub convert
{
    my $self = shift;
    my $record = shift;
    my $dest = shift;

    my $src = $self->get_source_filepath();

    print "Converting \"$src\" to \"$dest\"\n";
    return 0;

#     #my $extra_args = $self->{CONFIG}->get_single_value('extra_args', {'command_name' => 'flac_enc'});

#     my @tags;
#     foreach my $tagname ($record->get_all_keys())
#     {
#         push(@tags, $record->get_value_as_arg("--tag=$tagname=", $tagname));
#     }

#     my $status = Idval::Common::run($path,
#                                     Idval::Common::mkarglist(
#                                         $extra_args,
#                                         "-o",
#                                         "$dest",
#                                         @tags,
#                                         $src));

#     return $status;
}

1;
