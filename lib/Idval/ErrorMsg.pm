package Idval::ErrorMsg;

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
use Carp qw(croak cluck confess);
use Text::Wrap;

our $me = "me";
our $tellme = qq{Software error. Please report to \"$me\".};

our %builtinErrs =
    (
     'BadErrorID' => {
                      MSG => q{Unrecognized error message ID "%s"},
                      HELP => $tellme,
                     },
     'BadErrorLevel' => {
                      MSG => q{Unrecognized error level "%s" for message ID "%s"},
                      HELP => $tellme,
                     },
    );

our %level =
    (
     'WARN' => 'warn',
     'FATAL' => 'fatal',
     );

our %ErrorMsgs;

sub new
{
    my $class = shift;
    my $self = {};
    bless($self, ref($class) || $class);
    $self->_init(@_);
    return $self;
}

sub _init
{
    my $self = shift;
    my $msg_id = shift;

    if (!exists($ErrorMsgs{$msg_id}))
    {
        print "Message base: ", Dumper(\%ErrorMsgs);
        confess($self->safe_msg('BadErrorID', $msg_id));
    }

    $self->{MSG_ID} = $msg_id;
    if (!exists ($level{uc($ErrorMsgs{$msg_id}->{LEVEL})}))
    {
        confess($self->safe_msg('BadErrorLevel', $ErrorMsgs{$msg_id}->{LEVEL}, $msg_id));
    }

    $self->{LEVEL}  = $level{uc($ErrorMsgs{$msg_id}->{LEVEL})};
}

sub msg
{
    my $self = shift;
    my $msg_id = $self->{MSG_ID};

    # Do something more about debug levels here?
    return ($self->{LEVEL},
            wrap("", "", sprintf($ErrorMsgs{$msg_id}->{MSG}, @_)) . "\n" .
            wrap("", "", sprintf($ErrorMsgs{$msg_id}->{HELP}, @_)) . "\n\n");
}

sub safe_msg
{
    my $self = shift;
    my $msg_id = shift;

    # Do something about debug levels here?
    return wrap("", "", sprintf($builtinErrs{$msg_id}->{MSG}, @_)) . "\n" .
        wrap("", "", sprintf($builtinErrs{$msg_id}->{HELP}, @_)) . "\n\n";
}


sub make_msg
{
   my $msg_id = shift;

   my $error = new Idval::ErrorMsg($msg_id);

   return $error->msg(@_);
}

sub xml_msg
{
   my $msg_id = shift;

   my $error = new Idval::ErrorMsg($msg_id);

   return ({ID => $error->{MSG_ID}, LEVEL => $error->{LEVEL},
            MSG => wrap("", "", sprintf($ErrorMsgs{$msg_id}->{MSG}, @_)),
            HELP => wrap("", "", sprintf($ErrorMsgs{$msg_id}->{HELP}, @_))});
}

sub add_em
{
    my $argref = shift;
    my $id = $argref->{ID};

    $ErrorMsgs{$id}->{LEVEL} = $argref->{LEVEL};
    $ErrorMsgs{$id}->{MSG} = $argref->{MSG};
    $ErrorMsgs{$id}->{HELP} = $argref->{HELP};
}


#
# Beginning of error message list
#

sub create_error_message_list
{
    my $idv = 'idvalidator';
    my $me = 'me';
    my $tellme = "Internal software error. Please report this to \"$me\".";
    my $manpage = "perl $idv.pl --help";

    add_em({
        ID => "FileParse::BadContinuation",
        LEVEL => "FATAL",
        MSG  => "Stranded configuration line found: \"%s\"",
        HELP => "A continuation line was found, but nothing to continue from!\nA configuration ".
                "assignment must start at the beginning of a line (no spaces).",
           });

    add_em({
        ID => "Config::ConfigFileFail",
        LEVEL => "FATAL",
        MSG  => "Cannot open Idval configuration file \"%s\": %s",
        HELP => "This is serious! Make sure the file permissions are correct, or re-install Idval.",
           });

    add_em({
        ID => "Config::UserConfigFileFail",
        LEVEL => "FATAL",
        MSG  => "Cannot open specified configuration file \"%s\": %s",
        HELP => "Idval cannot open your personal configuration file. Please check the specified location \"%s\".",
           });

    add_em({
        ID => "Config::UserSyncFileFail",
        LEVEL => "FATAL",
        MSG  => "Cannot open specified sync file \"%s\": %s",
        HELP => "Idval cannot open your sync file. Please check the specified location \"%s\".",
           });

    add_em({
        ID => "Config::ValidateConfigFileFail",
        LEVEL => "FATAL",
        MSG  => "Cannot open specified validation configuration file \"%s\": %s",
        HELP => "Idval cannot open your validation configuration file. Please check the specified location \"%s\".",
           });

    add_em({
        ID => "Config::BadClassTypesDef",
        LEVEL => "FATAL",
        MSG => "No types declared in class definition \"%s\".",
        HELP => "A \"class\" command must specify at least one file-type that belongs in a class.",
           });

    add_em({
        ID => "Config::BadTypeDef",
        LEVEL => "FATAL",
        MSG => "Unrecognized extension definition \"%s\".",
        HELP => "Idval cannot parse this line, which is in one of your configuration files.",
           });

    add_em({
        ID => "Config::BadTypeExtDef",
        LEVEL => "FATAL",
        MSG => "No extensions declared in extension definition \"%s\".",
        HELP => "A \"type\" command must specify at least one file extension that indicates a file-type.",
           });

    add_em({
        ID => "Config::BadOp",
        LEVEL => "FATAL",
        MSG => "Unrecognized comparison operator \"%s\" in selector \"%s\".",
        HELP => "You must specify a valid comparison in a \"select\" statement. See $manpage for details.",
           });

    add_em({
        ID => "Config::BadConfigType",
        LEVEL => "FATAL",
        MSG => "Unrecognized configurator type \"%s\".",
        HELP => "$tellme",
           });

    add_em({
        ID => "Config::TooManySettings",
        LEVEL => "FATAL",
        MSG => "Only one \"%s\" setting is permitted in each validate block.",
        HELP => "See $manpage \"VALIDATION\" for details.",
           });

    add_em({
        ID => "Config::NotEnoughSettings",
        LEVEL => "FATAL",
        MSG => "One each of \"tagname\", \"value\" and \"gripe\" settings must be present in a validate block.",
        HELP => "See $manpage \"VALIDATION\" for details.",
           });

    add_em({
        ID => "Config::UnrecognizedFileType",
        LEVEL => "FATAL",
        MSG => "Unrecognized file type for file \"%s\".",
        HELP => "Idval only knows how to handle certain kinds of files.",
           });

    add_em({
        ID => "Record::UndefinedTag",
        LEVEL => "FATAL",
        MSG => "Undefined tag passed to tag_exists.",
        HELP => "$tellme",
           });

    add_em({
        ID => "Getters::BadVorbis",
        LEVEL => "FATAL",
        MSG => "Error from Vorbis conversion program: \"%s\" for file \"%s\"",
        HELP => "The program did not recognize this file as an ogg or flac file. Perhaps it has been corrupted?",
           });

    add_em({
        ID => "Writers::NoWriterDefined",
        LEVEL => "FATAL",
        MSG => "No tag writing program has been set for \"%s\" files.",
        HELP => "Idval cannot find a program to write tags for %s files. Perhaps you need to tell Idval exactly where the program is? See $manpage \"PROVIDERS\" for more information.",
           });

    add_em({
        ID => "Converters::NoConverterDefined",
        LEVEL => "FATAL",
        MSG => "No program is available to convert \"%s\" files to \"%s\" files.",
        HELP => "Idval cannot find a program to %s files into %s files. Perhaps you need to tell Idval exactly where the program is? See $manpage \"PROVIDERS\" for more information.",
           });

    add_em({
        ID => "Capability::UnknownCapability",
        LEVEL => "FATAL",
        MSG => "Unknown capability \"%s\" requested.",
        HELP => "$tellme",
           });

    add_em({
        ID => "Common::UnknownRegistration",
        LEVEL => "FATAL",
        MSG => "No common object registered with name \"%s\".",
        HELP => "$tellme",
           });

    add_em({
        ID => "Idval::NoRemoteTop",
        LEVEL => "WARN",
        MSG => "No remote top directory found for file \"%s\".",
        HELP => "$idv cannot tell where to put this file. This probably indicates an error in the sync configuration file.",
           });

    add_em({
        ID => "Idval::CannotReadFile",
        LEVEL => "FATAL",
        MSG => "Local file \"%s\" does not exist or cannot be read.",
        HELP => "Check the permissions on this file.",
           });
}

BEGIN { create_error_message_list(); }

1;
