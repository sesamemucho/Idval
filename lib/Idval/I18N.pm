package Idval::I18N;

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

# I18N files based on files from File::Findgrep.

use strict;
use warnings;
use Locale::Maketext 1.01;
use base ('Locale::Maketext');

sub idv_getkey
{
    my $self = shift;
    my $caller_id = shift;
    my $key_id = shift;

    my $key_matcher = $caller_id . '_' . $key_id . '=';

    my $key_val = $self->maketext($key_matcher . $key_id) || 
        die $self->maketext("No command found for [_1] command \"[_2]\"\n", $caller_id, $key_id);
    $key_val =~ s/^$key_matcher//;

    return $key_val;
}

# I decree that this project's first language is English.

our %Lexicon = (
  '_AUTO' => 1,
  # That means that lookup failures can't happen -- if we get as far
  #  as looking for something in this lexicon, and we don't find it,
  #  then automagically set $Lexicon{$key} = $key, before possibly
  #  compiling it.
  
  # The exception is keys that start with "_" -- they aren't auto-makeable.



  '_USAGE_MESSAGE' => 
   # an example of a phrase whose key isn't meant to ever double
   #  as a lexicon value
\q{
Usage:
    idv script usage.
},


  # Any further entries...

);
# End of lexicon.



1;  # End of module.

