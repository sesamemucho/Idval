package Idval::Provider;

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

use Config;
use File::Spec;
use List::Util;
use Data::Dumper;
use Carp;

use Idval::Constants;
use Idval::Common;
use Idval::FileIO;
use Idval::Record;

sub new
{
    my $class = shift;
    my $config = shift;
    my $name = shift;
    my $self = {};
    bless($self, ref($class) || $class);
    $self->{LOG} = Idval::Common::get_logger();
    $self->{PARAMS} = {};
    $self->{CONFIG} = $config;
    $self->{NAME} = $name;
    $self->{ENDPOINTS}->{PAIRS} = {};
    $self->{ENDPOINTS}->{SRCS} = {};
    $self->{ENDPOINTS}->{DESTS} = {};

    return $self;
}

sub query
{
    my $self = shift;
    my $key = shift;

    if (exists($self->{PARAMS}->{$key}))
    {
        return $self->{PARAMS}->{$key};
    }
    else
    {
        return;
    }
}

sub set_param
{
    my $self = shift;
    my $key = shift;
    my $value = shift;

    $self->{PARAMS}->{$key} = $value;

    return;
}

sub create_records
{
    my $self = shift;
    my $arglist = shift;

    my $fname   = $arglist->{filename};
    my $path    = $arglist->{path};
    my $class   = $arglist->{class};
    my $type    = $arglist->{type};
    my $srclist = $arglist->{srclist};

    my $rec = Idval::Record->new({FILE=>$path, CLASS=>$class, TYPE=>$type});

    $srclist->add($rec);

    return;
}

# endpoints are for use by the 'about' command

sub has_endpoint
{
    my $self = shift;
    my $from = uc shift;
    my $to = uc shift;
    my $endpoint = $from . ':' . $to;

    return exists ($self->{ENDPOINTS}->{PAIRS}->{$endpoint});
}

sub add_endpoint
{
    my $self = shift;
    my $from = uc shift;
    my $to = uc shift;
    my $endpoint = $from . ':' . $to;

    $self->{ENDPOINT}->{PAIR} = $endpoint;
    $self->{ENDPOINT}->{SRC} = $from;
    $self->{ENDPOINT}->{DEST} = $to;

    return $endpoint;
}

sub get_endpoint
{
    my $self = shift;

    return $self->{ENDPOINT}->{PAIR};
}

sub get_source
{
    my $self = shift;

    return $self->{ENDPOINT}->{SRC};
}

sub get_destination
{
    my $self = shift;

    return $self->{ENDPOINT}->{DEST};
}

sub get_source_filepath
{
    my $self = shift;
    my $rec = shift;

    return $rec->get_name();
}

sub get_dest_filename
{
    my $self = shift;
    my $rec = shift;
    my $dest_name = shift;
    my $dest_ext = shift;

    $dest_name =~ s{\.[^.]+$}{.$dest_ext}x;

    return $dest_name;
}

sub find_exe_path
{
    my $self = shift;
    my $name = shift || $self->{NAME};
    my $file = $name;
    my $exe = '';
    my $testexe;

    if ($^O ne 'VMS')
    {
        if (!Idval::FileIO::idv_test_exists($file))
        {
            $file .= $Config{_exe} unless $file =~ m/$Config{_exe}$/ix;
        }
    }

    foreach my $dir (File::Spec->path())
    {
        $testexe = File::Spec->catfile($dir, $file);
        if (Idval::FileIO::idv_test_exists($testexe))
        {
            $exe = $testexe;
            last;
        }
    }

    if (!$exe)
    {
        # Didn't find it in the path. Did the user specify a path?
        my $exelist = $self->{CONFIG}->get_list_value('command_path', {'command_name' => $name});

        foreach my $testexe (@{$exelist})
        {
            $self->{LOG}->verbose($DBG_PROCESS, "Checking \"$testexe\"\n");
            $testexe = Idval::Common::expand_tilde($testexe);
            if (-e $testexe)
            {
                $exe = $testexe;
                $self->{LOG}->verbose($DBG_PROCESS, "Found \"$testexe\"\n");
                last;
            }
        }
    }

    $exe = undef if !$exe;
    #croak("Could not find program \"$name\"\n") if !$exe;

    return $exe;
}

sub find_and_set_exe_path
{
    my $self = shift;
    my $name = shift || $self->{NAME};

    my $path = $self->find_exe_path($name);

    $self->set_param('path', $path);
    $self->set_param('is_ok', $path ? 1 : 0);
    $self->set_param('status', $path ? 'ok' : "Program \"$name\" not found.");

    return $path;
}

# For any plugin that needs to clean up
sub close
{
    my $self = shift;

    return 0;
}

1;
