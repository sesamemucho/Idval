package Idval::Plugins::Converters::Copy;

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
use Class::ISA;
use File::Copy;
use Time::HiRes qw (sleep);

use Idval::Common;
use Idval::Logger qw(chatty);
use base qw(Idval::Converter);

Idval::Common::register_provider({provides=>'converts', name=>'copy', from=>'*', to=>'*'});
#Idval::Common::register_provider({provides=>'converts', name=>'copy', from=>'*', to=>'*', weight=>200});

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
    $self->set_param('path', '(Builtin)');
    $self->set_param('is_ok', 1);
    $self->set_param('status', 'ok');

    return;
}

sub convert
{
    my $self = shift;
    my $tag_record = shift;
    my $dest = shift;

    my $src = $tag_record->get_name();

    $dest = Idval::Common::mung_path($dest);
    $src = Idval::Common::mung_path($src);

    chatty("Copying \"[_1]\" to \"[_2]\"\n", $src, $dest);
    #sleep(rand(10));
    return !copy($src, $dest);  # We want 0 for success
}

1;
