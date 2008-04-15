package Idval::Constants;

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

use base qw(Exporter);
    
our @EXPORT = qw(
            $DBG_STARTUP
            $DBG_PROCESS
            $DBG_CONFIG
            $DBG_PROVIDERS
            $DBG_ALL

            $SILENT
            $QUIET
            $INFO
            $VERBOSE
            $CHATTY

            $V1_ONLY
            $V2_ONLY
            $V2_PREFER
            );

our $DBG_STARTUP   = 1;
our $DBG_PROCESS   = 2;
our $DBG_CONFIG    = 4;
our $DBG_PROVIDERS = 8;

# ...

our $DBG_ALL     = 0xFFFFFFFF;

our $SILENT      = -1;
our $QUIET       = 0;
our $INFO        = 1;
our $VERBOSE     = 2;
our $CHATTY      = 3;

our $V1_ONLY     = 1;
our $V2_ONLY     = 2;
our $V2_PREFER   = 3;

1;
