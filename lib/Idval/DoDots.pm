package Idval::DoDots;

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

use Idval::Common;
use Idval::Logger qw(info_q);

my $dotnum;

sub init
{
    $dotnum = 0;
    return;
}

sub dodots
{
    my $char = shift;

    $dotnum++;
    info_q({force_match => 1}, "$char");
    info_q({force_match => 1}, " ") if $dotnum % 4 == 0;
    info_q({force_match => 1}, "\n") if $dotnum % 60 == 0;
 
    return;
}

sub finish
{
    info_q({force_match => 1}, "\n") if $dotnum % 60 != 0;

    return;
}

1;
