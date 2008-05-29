package Idval::FirstTime;
#
#
# XXX This really should be done during installation
#
#

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

use File::Basename ();
use File::Path ();
use File::Spec;

use Idval::Common;
use Idval::Constants;
use Idval::Config;

use vars qw(
            $VERSION
           );


$VERSION = substr q$Revision: 0.02 $, 10;

*prompt = Idval::Common::make_custom_logger({level => $SILENT,
                                             debugmask => $DBG_ALL,
                                             decorate => 0,
                                            });
*query = Idval::Common::make_custom_logger({query => 1,
                                            });


sub query_user
{
    my $prompt = shift;
    my $def = shift;
    my $auto_choose_def = shift;

    my $dispdef = defined $def ? "[$def] " : " ";
    $def = defined $def ? $def : "";

    local $| = 1;
    local $\ = undef;
    my $ans;
    if ($auto_choose_def)
    {
        $ans = $def;
        prompt("$prompt $dispdef $def");
        sleep(1.0);
    }
    else
    {
        $ans = query("$prompt $dispdef");
    }

    return (!defined $ans || $ans eq '') ? $def : $ans;
}

sub yesno
{
    my $result = query_user(@_);

    return $result =~ m/^y/ix;
}

sub init
{
    my $config = shift;

    my $selects = {config_group => 'idval_settings'};
    my $default;
    my $value;
    my $answer;

    my $prompt1 = <<"END_OF_PROMPT1";

First time setup:

idv is a program that can manage metadata in many kinds of files,
convert from one kind of file to another, validate metadata tags, and
many other things. There are a few things I need to know first.

If you don't want to set up the configuration right now, answer 'no'
to this question, and I'll try to set it automatically. If you want
to revisit the configuration later, use the command 'conf init' at the
idv prompt.

END_OF_PROMPT1
    prompt($prompt1);

    my $mc = yesno("Are you ready for manual configuration?", "yes", 0);
    my $auto_def = $mc ? 0 : 1;

    my $prompt1 = <<"END_OF_PROMPT2";

idv can use a file to store the metadata information between runs. It
isn\'t necessary, but it is convenient and saves quite a bit of time.

END_OF_PROMPT2
   $mc && prompt($prompt2);

    $value = $config->get_single_value('use_cache_file', $selects, 1);
    $default = $value ? 'yes' : 'no';

    $answer = yesno("Do you want to use a cache file?", "yes", $auto_def);





    prompt("\nmanual conf: $mc\n",
           "use cache file: $answer\n");


    return;
}

1;
