package Idval::FirstTime;
#
#
# XXX This really should be done during installation. Why??
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
use Text::Abbrev;

use Idval::Logger qw(:vars idv_print);
use Idval::Common;
use Idval::Config;
use Idval::Ui;

use vars qw(
            $VERSION
           );


$VERSION = substr q$Revision: 0.02 $, 10;

*query = Idval::Common::make_custom_logger({level => $L_SILENT,
                                            force_match => 1,
                                            query => 1,
                                            });

sub query_user
{
    my $argref = shift;

    my $prompt   = $argref->{prompt};
    my $def      = $argref->{default};
    my $choices  = exists $argref->{choices} ? $argref->{choices} : undef;
    # auto_def => automatically choose default
    my $auto_def = exists $argref->{auto_def} ? $argref->{auto_def} : 0;

    my $displayed_default = defined $def ? "[$def] " : " ";
    $def = defined $def ? $def : "";

    local $| = 1;
    local $\ = undef;
    my $ans;
    if ($auto_def)
    {
        $ans = $def;
        idv_print("$prompt $displayed_default $def");
        sleep(1.0);
        return $ans;
    }
    else
    {
        $ans = query("$prompt $displayed_default") || $def;
    }

    if (defined($choices))
    {
        my %abbrevs = abbrev(@{$choices});

        while (!exists($abbrevs{$ans}))
        {
            idv_print("Unrecognized response \"$ans\"\n");
            $ans = query("$prompt $displayed_default") || $def;
        }

        $ans = $abbrevs{$ans};
    }

    return $ans;
}

sub query_list
{
    my $argref = shift;

    my $prompt   = $argref->{prompt};
    my $def      = $argref->{default};
    my $choiceref  = $argref->{choices};
    my @choices = @{$choiceref};
    # auto_def => automatically choose default
    my $auto_def = exists $argref->{auto_def} ? $argref->{auto_def} : 0;

    my $displayed_default = defined $def ? "[$def] " : " ";

    local $| = 1;
    local $\ = undef;

    for my $i (0..$#choices)
    {
        idv_print(sprintf("%2d %s\n", $i, $choices[$i]));
    }

    my $ans;
    if ($auto_def)
    {
        $ans = $def;
        idv_print("$prompt $displayed_default $def");
        sleep(1.0);
        return $choices[$ans];
    }
    else
    {
        $ans = query("$prompt $displayed_default");
        $ans = $ans eq '' ? $def : $ans;
    }

    print "num choices: $#choices\n"; 
    while ($ans < 0 or $ans > $#choices)
    {
        idv_print("Response \"$ans\" is outside the range\n");
        for my $i (0..$#choices)
        {
            idv_print(sprintf("%2d %s\n", $i, $choices[$i]));
        }
        $ans = query("$prompt $displayed_default");
        $ans = $ans eq '' ? $def : $ans;
        
    }

    return $choices[$ans];
}

sub yesno
{
    my $prompt = shift;
    my $default = shift;
    my $auto_def = shift;
    my $result = query_user({prompt => $prompt,
                             default => $default,
                             choices => [qw( yes no )],
                             auto_def => $auto_def});

    return ($result =~ m/^y/ix) ? 1 : 0;
}

sub init
{
    my $config = shift;

    my $selects = {config_group => 'idval_settings'};
    my $default;
    my $value;
    my $answer;

    idv_print(qq{

First time setup:

idv is a program that can manage metadata in several kinds of files,
convert from one type of file to another, validate metadata tags, and
many other things. There are a few things I need to know first.

If you don't want to set up the configuration right now, answer 'quit'
to this question, and the program will exit without having made any
changes to the configuration. If you want me to try to set it up
automatically, answer 'auto'. Otherwise, answer 'yes' to start the
manual configuration.
});

    my $mc = query_user({prompt => "Are you ready for manual configuration?",
                         default => "yes",
                         choices => [qw(auto yes no)]});

    my $auto_def = $mc eq 'auto' ? 1 : 0;

    my @choices;

# Is there a userconfig file already?

    my $user_config_file = Idval::Ui::get_userconfig_file();

    if ($user_config_file)
    {
idv_print(qq{

I see you already have a user configuration file
(\"$user_config_file\"). This is a bit problematic, since I can't
(yet) automatically modify it. If you want to save it, please answer
'no' to this question, and move it out of the way.

});
        $answer = yesno("Shall I delete your current user configuration file?",
                       "no",
                       $auto_def);

        if ($answer)
        {
            unlink $user_config_file;
        }
        else
        {
            exit;
        }
    }

    @choices = Idval::Ui::get_userconfig_file_choices();
    idv_print(qq{

idv needs a file in which to store customization data. Please choose
one of the following.
});

    $mc = query_list({prompt => "User configuration file name: ",
                      default => 0,
                      choices => \@choices,
                      auto_def => $auto_def});

   print "Got \"$mc\"\n";
    my $user_config_file = $mc;

    #$answer = yesno("Do you want to use a cache file?", "yes", $auto_def);

    return;
}

1;
