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

use English '-no_match_vars';
use File::Basename ();
use File::Path ();
use File::Spec;
use Text::Abbrev;
use Data::Dumper;

use Idval::I18N;
use Idval::Logger qw(:vars idv_print idv_print_noi18n query fatal);
use Idval::Common;
use Idval::FileIO;
use Idval::Ui;

use vars qw(
            $VERSION
           );

$VERSION = substr q$Revision: 0.02 $, 10;

sub new
{
    my $class = shift;
    my $self = {};
    bless($self, ref($class) || $class);
    Idval::Common::register_common_object('providers', $self);
    $self->_init(@_);

    return $self;
}

sub _init
{
    my $self = shift;
    $self->{LH} = Idval::I18N->idv_get_handle() || die "Idval::FirstTime: Can't get a language handle!";
    return;
}

sub query_user
{
    my $self = shift;
    my $argref = shift;
    my $prompt   = $self->{LH}->maketext($argref->{prompt});
    my $help     = exists $argref->{help} ? $argref->{help} : '';
    my $def      = $argref->{default};
    my $choices  = exists $argref->{choices} ? $argref->{choices} : [];
    # auto_def => automatically choose default
    my $auto_def = exists $argref->{auto_def} ? $argref->{auto_def} : 0;

    $def = defined $def ? $self->{LH}->maketext($def) : '';
    my %i18n_choices;
    my $i18n_choice;
    foreach my $choice (@{$choices})
    {
        $i18n_choice = $self->{LH}->maketext($choice);
        $i18n_choices{$i18n_choice} = $choice;
    }

    my $displayed_default = $def ? "[$def] " : " ";

    local $| = 1;
    local $\ = undef;
    my $ans;
    if ($auto_def)
    {
        $ans = $def;
        # text should already be localized
        idv_print_noi18n("$prompt $displayed_default $def");
        sleep(1.0);
        return $ans;
    }
    else
    {
        # text should already be localized
        $ans = query("$prompt $displayed_default") || $def;
    }

    if (@{$choices})
    {
        my %abbrevs = abbrev(@{$choices});

        while (!exists($abbrevs{$ans}))
        {
            idv_print("Unrecognized response \"[_1]\"\n", $ans);
            idv_print($help);
            # text should already be localized
            $ans = query("$prompt $displayed_default") || $def;
        }

        $ans = $abbrevs{$ans};

        fatal("unrecognized entry \"[_1]\" in user_choice\n", $ans) unless exists $i18n_choices{$ans};
        return $i18n_choices{$ans};
    }

    return $ans;
}

sub query_list
{
    my $self = shift;
    my $argref = shift;

    my $prompt   = $self->{LH}->maketext($argref->{prompt});
    my $help     = exists $argref->{help} ? $argref->{help} : '';
    my $def      = $argref->{default};
    my $choiceref  = $argref->{choices};
    my @choices = @{$choiceref};
    # auto_def => automatically choose default
    my $auto_def = exists $argref->{auto_def} ? $argref->{auto_def} : 0;

    $def = defined $def ? $self->{LH}->maketext($def) : '';
    my $displayed_default = defined $def ? "[$def] " : " ";

    my @i18n_choicelist;
    my $i18n_choice;
    foreach my $choice (@choices)
    {
        $i18n_choice = $self->{LH}->maketext($choice);
        push(@i18n_choicelist, $i18n_choice);
    }

    local $| = 1;
    local $\ = undef;

    for my $i (0..$#choices)
    {
        idv_print("[sprintf,%2d %s,_1,_2]\n", $i, $i18n_choicelist[$i]);
    }

    my $ans;
    if ($auto_def)
    {
        $ans = $def;
        # text should already be localized
        idv_print_noi18n("$prompt $displayed_default $def");
        sleep(1.0);
        return $choices[$ans];
    }
    else
    {
        # text should already be localized
        $ans = query("$prompt $displayed_default");
        $ans = $ans eq '' ? $def : $ans;
    }

    while ($ans < 0 or $ans > $#choices)
    {
        idv_print("Response \"[_1]\" is outside the range\n", $ans);
        for my $i (0..$#choices)
        {
            idv_print("[sprintf,%2d %s,_1,_2]\n", $i, $i18n_choicelist[$i]);
        }
        # text should already be localized
        $ans = query("$prompt $displayed_default");
        $ans = $ans eq '' ? $def : $ans;

    }

    return $choices[$ans];
}

# default must be either 'yes' or 'no' (it is localized in query_user)
sub yesno
{
    my $self = shift;
    my $argref = shift;

    my $help = exists $argref->{help} ? $argref->{help} : '~yesno_help';
    $argref->{help} = $help;
    $argref->{choices} = [qw(yes no)];
    my $result = $self->query_user($argref);

    return (lc $result eq 'yes') ? 1 : 0;
}

sub setup
{
    my $self = shift;

    my $user_config_file;
    my $userfiles_dirname;

    while(1)
    {
        idv_print('~first_time_setup');
        my $mc = $self->query_user({prompt => '~first_time_setup_prompt',
                                    help => '~first_time_setup',
                                    default => 'yes',
                                    choices => [qw(auto yes no quit)]});

        if ($mc eq 'no' or $mc eq 'quit')
        {
            idv_print("manual configuration cancelled\n");
            return;
        }

        my $auto_def = $mc eq 'auto' ? 1 : 0;

        my @choices;

        # Is there a userconfig file already?

        $user_config_file = Idval::Ui::get_userconfig_file();

        if ($user_config_file)
        {
            idv_print('~first_time_delete_cfg_file', $user_config_file);
            $mc = $self->yesno({
                prompt =>'~first_time_delete_cfg_file_prompt',
                default=>"no",
                auto   => $auto_def});

            if (!$mc)
            {
                exit;
            }

        }

        @choices = Idval::Ui::get_userconfig_file_choices();

        idv_print('~first_time_userconfig_filename');

        $mc = $self->query_list({prompt => '~first_time_userconfig_filename_prompt',
                                 default => 0,
                                 choices => \@choices,
                                 auto_def => $auto_def});

        print "Got file name \"$mc\"\n";
        $user_config_file = Idval::Common::expand_tilde($mc);

        my $default_userfiles_dir = File::Spec->catdir(
            $ENV{HOME},
            $self->{LH}->maketext('~first_time_userfiles_dir_dirname'));

        my $user_entry = $self->{LH}->maketext('~first_time_user_entry');
        @choices = ($default_userfiles_dir, $user_entry);

        idv_print('~first_time_userfiles_dir');

        $mc = $self->query_list({prompt => '~first_time_userfiles_dir_prompt',
                                 help => '~first_time_userfiles_dir',
                                 default => 0,
                                 choices => \@choices,
                                 auto_def => $auto_def});

        if ($mc eq $user_entry)
        {
            $mc = $self->query_user({prompt => '~first_time_userfiles_dir_free_prompt',
                                     help => '~first_time_userfiles_dir_free_prompt'});
        }

        print "Got dir name \"$mc\"\n";
        $userfiles_dirname = Idval::Common::expand_tilde($mc);

        # We have all the information we need:
        #   (if we've reached here) A new user config file will be created
        #   the name of the new user config file
        #   the name of the user files directory

        # review and approve

        idv_print('~first_time_review', $user_config_file, $userfiles_dirname);
        $mc = $self->query_user({prompt => '~first_time_review_prompt',
                                 help => '~first_time_review_prompt',
                                 default => 'yes',
                                 choices => [qw(yes no cancel)]});

        if ($mc eq 'cancel')
        {
            idv_print("manual configuration cancelled\n");
            return;
        }

        if ($mc eq 'yes')
        {
            last;
        }
    }

    unlink $user_config_file;
    if (!Idval::FileIO::idv_test_isdir($userfiles_dirname))
    {
        Idval::FileIO::idv_mkdir($userfiles_dirname);
    }

    my $out = Idval::FileIO->new($user_config_file, '>') or
        fatal("Can't open new user configuration file [_1] for writing: [_2]\n",
              $user_config_file,
              $ERRNO);
    $out->print($self->{LH}->maketext('~first_time_config_contents', $userfiles_dirname));
    $out->close();

    idv_print("Configuration setup finished.\n");

    return;
}

1;
