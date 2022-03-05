package Idval::Help;

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

use Pod::Usage;
use Pod::Select;
use Data::Dumper;
use File::Find;

use Idval::I18N;
use Idval::Logger qw(chatty fatal);
use Idval::Common;
use Idval::FileIO;

my $help_info;
our $pod_file;
our $first = 1;
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

    $self->{LH} = Idval::I18N->get_handle() || die "Can't get a language handle!";

    $self->{LANGUAGES} =  [
      map {
        my $it = $_;  # copy
        $it =~ tr<-A-Z><_a-z>; # lc, and turn - to _
        $it =~ tr<_a-z0-9><>cd;  # remove all but a-z0-9_
        $it;
      } ($self->{LH}->language_tag(), $self->{LH}->fallback_languages())
    ];

    print "from HELP: langs are: ", Dumper($self->{LANGUAGES});
}

sub set_man_info
{
    my $self = shift;
    my $src = shift;
    my $info = shift;

    print "Setting info for \"$src\"\n";
    if (defined($info))
    {
        # Make sure it's clean
        $info =~ s/^\s+//;
        $help_info->{MAN}->{''}->{$src} = $info;
    }

    return;
}

sub man_info
{
    my $self = shift;
    my $src = shift;
    my $package = shift || '';

    #print ("help_info: ", Dumper($help_info->{MAN}->{$package})), $first = 0 if $first;
    return $help_info->{MAN}->{$package}->{$src} if exists $help_info->{MAN}->{$package}->{$src};

    # Otherwise, look for it in the localized pod tree
    my $pod = $self->get_localized_pod($src, $package);
    if ($pod)
    {
        $help_info->{MAN}->{$package}->{$src} = $pod;
        return $pod;
    }

    return;
}

sub get_localized_pod
{
    my $self = shift;
    my $podname = shift;
    my $package = shift;

    my @package_path = split(/::/, $package);
    pop @package_path;          # The idea is that pods should inhabit
                                # a tree that looks like the .pm tree,
                                # so (for instance), the pod for the
                                # package Idval::Common should be
                                # Idval/Common.pod, not
                                # Idval/Common/Common.pod.
    my $pod_dir;
    #my $pod_file;
    my $got_it;

    # It may happen that $package is empty, so we should just search from the top dir, and hope
    # that podname is unique.

    foreach my $lang_tag (@{$self->{LANGUAGES}})
    {
        $pod_dir = Idval::Common::get_top_dir('I18N', 'pods', $lang_tag, @package_path);
        next unless -d $pod_dir;
        my $wanted = sub {
            if ($_ eq $podname . '.pod')
            {
                $Idval::Help::pod_file = $File::Find::name;
                $File::Find::prune = 1;
            }
            return;};

        $pod_file = '';
        find($wanted, $pod_dir);

        if ($pod_file)
        {
            chatty("Found localized pod at [_1]\n", $pod_file);
            last;
        }
        else
        {
            chatty("No localized pod \"[_1].pod\" in [_2]\n", $podname, $pod_dir);
        }
    }

    my $pod = '';
    if ($pod_file)
    {
        my $fh = Idval::FileIO->new($pod_file, "r");
        fatal("Bad filehandle: [_1] for item \"[_2]\"", $!, $pod_file) unless defined $fh;
        $pod .= do { local $/ = undef; <$fh> };
        $fh->close();
    }

    return $pod;
}

sub detailed_info_ref
{
    my $self = shift;
    my $src = shift;
    my $pkg = shift;
    my $info = shift;

    $help_info->{DETAIL}->{$src}->{$pkg} = $info if defined($pkg);

    return $help_info->{DETAIL}->{$src};
}

sub _call_pod2usage
{
    my $self = shift;
    my $name = shift;
    my @sections = @_;

    my $usage = '';
    my $temp_store = '';

    my $input = $self->man_info($name);
    return "$name: no information available" unless defined($input);

    #print "For $name (in", join(':', @sections), "), input is \"$input\"\n";
    open(my $INPUT, '<', \$input) || die "Can't open in-core filehandle for pod_input: $!\n";
    open(my $TEMP, '>', \$temp_store) || die "Can't open in-core filehandle for temp_store: $!\n";
    my $selector = new Pod::Select();
    $selector->select(@sections);
    $selector->parse_from_file($INPUT, $TEMP);
    close $TEMP;
    close $INPUT;

    open($INPUT, '<', \$temp_store) || die "Can't open in-core filehandle for reading temp_store: $!\n";
    open(my $FILE, '>', \$usage) || die "Can't open in-core filehandle: $!\n";
    my $parser = new Pod::Text();
    $parser->parse_from_filehandle($INPUT, $FILE);
    close $FILE;
    close $INPUT;
    #print "returning usage \"$usage\"\n";
    return $usage;
}

sub get_short_description
{
    my $self = shift;
    my $name = shift;
    my $usage = $self->_call_pod2usage($name, "NAME");

    # Now trim it
    $usage =~ s/Name\s*//si;
    $usage =~ s/\n\n*/\n/gs;
    $usage =~ s/\n*$//;
    return $usage;
}

sub get_full_description
{
    my $self = shift;
    my $name = shift;

    my $usage = $self->_call_pod2usage($name, '');

    return $usage;
}

sub get_synopsis
{
    my $self = shift;
    my $name = shift;

    my $usage = $self->_call_pod2usage($name, 'SYNOPSIS', 'OPTIONS');

    return $usage;
}

1;
