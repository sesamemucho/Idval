package Idval::Plugins::Converters::Sox;

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
use Data::Dumper;

use Idval::Logger qw(verbose idv_dbg fatal);

use base qw(Idval::Converter);

Idval::Common::register_provider({provides=>'filters', name=>'sox', from=>'WAV', to=>'WAV', attributes=>'filter'});

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
    $self->set_param('filetype_map', {'WAV' => [qw{ wav }]});
    $self->set_param('classtype_map', {'MUSIC' => [qw( WAV )]});
    # Since we have a choice, tell the typemapper that we want our
    # output files to have a '.wav' extension
    $self->set_param('output_ext_map', {'WAV' => [qw( wav )]});

    $self->find_and_set_exe_path('sox');

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

    my $path = $self->query('path');

    my $sox_args = $self->{CONFIG}->i18n_get_single_value('config', 'sox_args', $tag_record);

    if (!$sox_args)
    {
        my $vars = $self->{CONFIG}->merge_blocks($tag_record);

        idv_dbg("No sox args. merge_blocks result is: [_1]", Dumper($vars));
        fatal("sox filter was called, but there were no arguments in \"sox_args\". Selectors are [_1]", Dumper($tag_record));
    }

    my @sox_args_list = split(' ', $sox_args);
    grep(s/%INFILE%/$src/, @sox_args_list);
    grep(s/%OUTFILE%/$dest/, @sox_args_list);

    verbose("sox filter command: [_1] [_2]\n", $path, join(' ', Idval::Common::mkarglist(@sox_args_list)));

    my $status = Idval::Common::run($path, Idval::Common::mkarglist(@sox_args_list));

    return $status;
}

=pod

=head1 NAME

sox - Filters WAV to WAV using sox

=head1 DESCRIPTION

Each sync configuration descriptor that wants to use a sox filter must
have two variables set:

   filter = sox

   sox_args = <arguments to pass to the sox command>

In sox_args, the input file is represented by %INFILE% and the output
file is represented by %OUTFILE%.

=head1 EXAMPLES

sox_args = %INFILE% %OUTFILE% lowp 1000.0

filters the input file through a low-pass filter

sox_args = %INFILE% %OUTFILE% echo 0.8 0.9 1000.0 0.3

puts echoes on the input file.

sox_args = %INFILE% %OUTFILE% flanger 0.6 0.87 3.0 0.9 0.5 -s

runs the input file through a flanger effect.

sox_args = %INFILE% %OUTFILE% fade 0 29.0 1.0

will make the output file be the first thiry seconds of the input
file.

=cut

1;
