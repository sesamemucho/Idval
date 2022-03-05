package Idval::Command;

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

use Data::Dumper;

use Idval::Logger qw(chatty fatal);
use Idval::Common;

#
# A Command is a lot like a Provider, except that we don't require it
# to be written as a class. It would be very handy to have a command
# be an object, though, so Idval::Command is a wrapper around a
# command script to make it work like a Provider.
#

use base qw(Idval::Provider);

sub new
{
    my $class = shift;
    my $config = shift;
    my $name = shift;
    my $cmd_pkg = shift;

    my $self = $class->SUPER::new($config, $name);
    bless($self, ref($class) || $class);
    $self->init($cmd_pkg);
    return $self;
}

sub init
{
    my $self = shift;
    my $cmd_pkg = shift;

    $self->{CMD_PKG} = $cmd_pkg;

    chatty("Idval::Command creating object from \"[_1]\"\n", $cmd_pkg);

    # The first time a command is encountered, if it has an "init" routine, call it
    no strict 'refs';
    my $pkghash = "${cmd_pkg}::";
    if (exists(${$pkghash}{'init'}))
    {
        my $init_name = "${cmd_pkg}::init";
        &$init_name();
    }
    use strict;

    $self->set_param('is_ok', 1);
    return;
}

sub main
{
    my $self = shift;

    my $cmd_pkg = $self->{CMD_PKG};
    no strict 'refs';
    my $pkghash = "${cmd_pkg}::";
    if (exists(${$pkghash}{'main'}))
    {
        my $cmd = "${cmd_pkg}::main";
        return &$cmd(@_);
    }
    else
    {
        fatal("No \"main\" routine in command \"[_1]\"\n", $cmd_pkg);
    }

    use strict;

    return;
}

1;
