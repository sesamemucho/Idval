package Idval::NewFH;

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
use base qw(IO::File);

sub save_filename {
    my $glob = shift;
    my $fname = shift;

    ${$glob}->{SAVE_FILENAME} = $fname;

    return;
}

sub get_filename {
    my $glob = shift;

    return ${$glob}->{SAVE_FILENAME};
}

1;
