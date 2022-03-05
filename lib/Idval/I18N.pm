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
use Carp;
use Locale::Maketext 1.01;
use base ('Locale::Maketext');

# Don't use any Idval:: modules before checking (and maybe fixing) t/accept/10I18Test.t

our $idv_lang_test_hook = '';

# Allow for localization of command names, configuration file keys,
# etc.  Call this routine with a context and a key name:
# $lh->idv_getkey('config', 'initfiles'). The context argument is
# there to allow different modules or commands to use the same key
# name. For instance, the 'set' command has a subcommand 'debug', and
# would use the call $lh->idv_getkey('set', 'debug') to get the
# localized name of 'debug'. Since we don't want 'set' to be the only
# thing that can use the key 'debug', idv_getkey has a context
# argument, so (for example) if the 'foo' command also wants to use
# 'debug', it would use the call $lh->idv_getkey('foo', 'debug').
#
# Don't take this too far, though. Any key that would be used in a
# config file should _probably_ use the 'config' context, whatever
# module or command happens to actually use it.
#
# Setting up in the Lexicon.
#
# First, recall that Locale::Maketext works by substituting
# strings. This means that we need a string that has the context plus
# the key_id for the key and a string that has the context plus the
# new name as the value. For example, in the Lexicon for Pig Latin, to
# translate $lh->idv_getkey('config', 'initfiles') we will have the
# assignment
# 'config=initfiles' => 'config=initfilesway', and for
# $lh->idv_getkey('foo', 'debug') we would have
# 'foo=debug' => 'foo=ebugday'.

sub idv_getkey
{
    my $self = shift;
    my $context = shift;
    my $key_id = shift;

    my $key_matcher = $context . '=';

    my $key_val = $self->maketext($key_matcher . $key_id) ||
        die $self->maketext("No command found for [_1] command \"[_2]\"\n", $context, $key_id);
    #print STDERR "idv_getkey: with \"$key_matcher\" and \"$key_id\", got \"$key_val\"\n";
    $key_val =~ s/^$key_matcher//;

    return $key_val;
}

# For use with GetOptions.
# Input: list of options
#        hash of option-initial-values
#
# The 'list of options' should be an array containing GetOptions
# option-specs (for instance, "help", "filename=s", "count:i", etc.)
#
# The 'hash of option-initial-values' should be, well, a hash of
# initial values for the options. It isn't necessary that all options
# have initial values. The option keys should be the option-specs
# without the argument-specs (from above, "help", "filename",
# "count", etc.).
#
# This routine will translate all the option names ("help",
# "filename", "count"), and return the translated 'list of options',
# and 'hash of option-initial-values'.

sub idv_translate_options
{
    my $self = shift;
    my $option_list_in = shift;
    my $option_hash_in = shift;

    my %option_names;
    my @option_list;
    my %option_hash;

    my $translated_name;
    my $name_spec;
    my $arg_spec;

    foreach my $opt_spec (@{$option_list_in})
    {
        ($name_spec, $arg_spec) = ($opt_spec =~ m/^(.*?)(!|\+|=.*|:.*)?$/);
        #print STDERR "name spec is: \"$name_spec\", arg_spec is \"$arg_spec\", opt_spec is \"$opt_spec\"\n";
        confess "uninitialized name spec" unless $name_spec;
        $option_names{$name_spec} = $self->idv_getkey('options', $name_spec);
        print STDERR "2 name spec is: \"$name_spec\", option_names{ns} is \"$option_names{$name_spec}\"\n";
        push(@option_list, $option_names{$name_spec} . (defined $arg_spec ? $arg_spec : ''));
    }

    foreach my $opt_name (keys %{$option_hash_in})
    {
        $option_names{$opt_name} = $self->idv_getkey('options', $opt_name);
        $option_hash{$option_names{$opt_name}} = $option_hash_in->{$opt_name};
    }

    return (\%option_names, \@option_list, \%option_hash);
}

sub idv_set_language
{
    $idv_lang_test_hook = shift;

    return;
}

sub idv_get_handle
{
    my $class = $_[0];
    #my $chosen_language = $Config_settings{'language'};
    my $chosen_language = $idv_lang_test_hook;
    my $lh;

    #my $chosen_language = defined %Idval::I18N::Test::Acceptance:: ? Idval::I18N::Test::Acceptance::test_language() : '';

    if($chosen_language) {
        $lh = $class->get_handle($chosen_language)
            || die "No language handle for \"$chosen_language\" or the like";
    } else {
        # Config file missing, maybe?
        $lh = $class->get_handle()
            || die "Can't get a language handle";
    }

    return $lh;
}

# I decree that this project's first language is English.

our %Lexicon = (
  # Any further entries...

    '_AUTO' => 1,

    '~yesno_help' => <<'EOF',
yes: agree to the question; perform the action
no : disagree with the question; do not perform the action
EOF

    '~first_time_setup' => <<'EOF',

First time setup:

idv is a program that can manage metadata in several kinds of files,
convert from one type of file to another, validate metadata tags, and
many other things. There are a few things I need to know first.

If you don't want to set up the configuration right now, answer 'quit'
or 'no' to this question, and the program will exit without having
made any changes to the configuration. If you want me to try to set it
up automatically, answer 'auto'. Otherwise, answer 'yes' to start the
manual configuration.

EOF

'~first_time_setup_prompt' => <<'EOF',
Are you ready for manual configuration?
EOF


'~first_time_delete_cfg_file' => <<'EOF',

I see you already have a user configuration file
("[_1]"). This is a bit problematic, since I can't
(yet) automatically modify it. If you want to save it, please answer
'no' to this question, and move it out of the way.

EOF

'~first_time_delete_cfg_file_prompt' => <<'EOF',
Shall I delete your current user configuration file?
EOF

'~first_time_userconfig_filename' => <<'EOF',
idv needs a file in which to store customization data. Please choose
one of the following.
EOF

'~first_time_userconfig_filename_prompt' => <<'EOF',
User configuration file name:
EOF

'~first_time_user_entry' => 'Enter filename',

'~first_time_userfiles_dir' => <<'EOF',
idv needs a folder in which to store data generated by the idv
program, and also to hold any user-generated scripts.  Please choose
one of the following.
EOF

'~first_time_userfiles_dir_prompt' => <<'EOF',
User files directory name:
EOF

'~first_time_userfiles_dir_free_prompt' => 'Please enter user files directory name:',

'~first_time_userfiles_dir_dirname' => '.idval',

'~first_time_review' => <<'EOF',
First-time configuration is almost finished.
The name of the user configuration file is [_1].
The name of the user files directory is [_2].
EOF

'~first_time_review_prompt' => <<'EOF',
Is this correct? Answer 'yes' to approve, 'no' to re-enter the
information, or 'cancel' to cancel.
EOF

'~first_time_config_contents' => <<'EOF',
{
    # Collect settings of use only to overall Idval configuration
    config_group == idval_settings

    user_dir = [_1]
    command_dir += %user_dir%/commands
    data_store   = %user_dir%/data_store
}

# Add customizations here
EOF

);

# End of lexicon.



1;  # End of module.

