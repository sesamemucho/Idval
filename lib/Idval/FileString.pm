#
# Provides an interface to the file system. We will use either
# this module or FileString.pm (for testing).
#
# This module emulates filesystem access through a data structure.
#
package Idval::FileString;

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
use Carp;
use Data::Dumper;
use File::Spec;
use File::Basename;
use File::Find;
use IO::String;

use base qw(IO::String);

our $tree = {};
our $pwd = '/';
our $cwd = $tree;
our $cb;
our @curdir;

# This seems to be needed for AUTOLOAD to work
sub new
{
    my $class = shift;
    my $filename = shift || '';
    my $mode = shift || '';

    my $io;

    if ($filename && ($mode && ($mode =~ m/^[r<]/)) && idv_test_exists($filename))
    {
        $io = IO::String->new(idv_get_file($filename));
    }
    else
    {
        $io = IO::String->new;
    }

    #print STDERR Dumper($io);
    return $io;
}

sub open
{
    my $self = shift;
    my $filename = shift;
    my $mode = shift;
    my $perms = shift;

    if ($mode && ($mode =~ m/^r/))
    {
        if (!idv_test_exists($filename))
        {
            $self->open(undef);
        }

        $self->open(idv_get_file($filename));
    }
}

#XXX Need to change directories to ...->{dirname}->{NAME} = "dirname"
#                                  ...->{dirname}->{FILES}->{}
#   and files to                   ...->{filename}->{NAME} = "filenamename"
#                                  ...->{filename}->{CONTENTS} = "..."
# sub _idv_find_impl
# {
#     my $dirpath = shift;

#     foreach my $key (keys %{$dirpath})
#     {
#         #print STDERR "Checking key \"$key\"\n";
#         if (! $key)
#         {
#             next;
#         }
#         elsif (ref $dirpath->{$key} eq "HASH")
#         {
#             idv_cd($key);
#             local $_ = $key;
#             local $File::Find::dir = File::Spec->catdir(@curdir);
#             local $File::Find::name = File::Spec->catfile(@curdir, $key);

#             &$cb();

#             push(@curdir, $key);
#             #print STDERR "1 curdir is: ", join('+', @curdir), " key is $key (is a directory)\n";
#             _idv_find_impl($dirpath->{$key});
#             pop(@curdir);
#             idv_cd('..');
#         }
#         else
#         {
#             local $_ = $key;
#             local $File::Find::dir = File::Spec->catdir(@curdir);
#             local $File::Find::name = File::Spec->catfile(@curdir, $key);

#             #print STDERR "2 curdir is: ", join('+', @curdir), " key is $key (is a file)\n";

#             &$cb();
#         }
#     }
# }


sub _idv_find_impl
{
    my $dir = shift;
    my $entry = shift;

    return if ref $dir->{$entry} ne '';
    
    my $dirname = idv_get_dirname($dir);
    idv_cd($dir);

    local $_ = $entry;
    local $File::Find::dir = $dirname;
    local $File::Find::name = $dirname . "/$entry";

    &$cb();
}


sub idv_find
{
    my $subr = shift;
    my @dirs = @_;
    my $here = $cwd;
    my $status;
    my $dir_ref;

    @dirs = ('.') unless @dirs;
    local $cb = $subr;
    #local @curdir = split('/', $here);
    #print STDERR "0 curdir is: \"", join('+', @curdir), "\" size is ", scalar(@curdir), " pwd is \"$here\"\n";

    #print STDERR "dirs are: \"", join(',', @dirs), "\"\n";
    #print STDERR Dumper($tree);
    foreach my $dir (@dirs)
    {
        if ($dir eq '.')
        {
            $dir_ref = $cwd;
        }
        else
        {
            ($status, $dir_ref) = _get_dir($dir);
            next if $status != 0;
        }

        _idv_visit($dir_ref, \&_idv_find_impl);
    }

    idv_cd($here);
}

# A simple minded implementation for testing.
# GLOBBING ONLY DONE ON FILENAME (NOT DIRECTORY NAMES)
# No brace expansion
# No wildcard escapes
# No tilde expansion.
# Never ignore case.
sub idv_glob
{
    my $filespec = shift;

    $filespec =~ s/\./\\./g;
    $filespec =~ s/\*/.*/g;
    $filespec =~ s/\?/./g;

    my ($vol, $dirpath, $filename) = File::Spec->splitpath($filespec);
    my ($status, $dpath) = _get_dir($dirpath);
    my $dirname = idv_get_dirname($dpath);

    my @filelist = ();
    my $candidate;
    foreach my $fname (keys(%{$dpath}))
    {
        $candidate = $dirname . '/' . $fname;
        push (@filelist, $candidate) if $candidate =~ m/^$filespec/;
    }

    return sort @filelist;
}

sub idv_cd
{
    my $new_cd = shift;

    if (ref $new_cd)
    {
        $cwd = $new_cd;
    }
    else
    {
        my ($status, $dpath) = _get_dir($new_cd);
        
        $cwd = $dpath if $status == 0;
    }
}

sub idv_pwd
{
    return $cwd;
}

# Given a directory node, return the absolute directory name
sub idv_get_dirname
{
    my $dir = shift;
    my @name = ();
    my $tdir = {};
    my $i;

    while (exists($dir->{'..'}))
    {
        $i++;
        $tdir = $dir->{'..'};

        foreach my $name (keys %{$tdir})
        {
            if (ref $tdir->{$name} and $tdir->{$name} == $dir)
            {
                push(@name, $name);
                last;
            }
        }

        $dir = $tdir;

        if ($i > 128)
        {
            croak "Maximum directory depth exceeded. So far, the name is: \"" .
                '/' . join('/', reverse @name) . "\"";
        }
    }

    return '/' . join('/', reverse @name);
}

sub _idv_add_special
{
    my $dir = shift;
    my $entry = shift;

    return if ref $dir->{$entry} eq '';
    $dir->{$entry}->{'..'} = $dir unless exists $dir->{$entry}->{'..'};
}

sub _idv_remove_special
{
    my $dir = shift;
    my $entry = shift;

    return if ref $dir->{$entry} eq '';
    delete($dir->{$entry}->{'..'}) if exists $dir->{$entry}->{'..'};
}

sub _idv_visit
{
    my $top = shift;
    my $rtn = shift;

    return if ref $top eq '';
    foreach my $item (keys %{$top})
    {
        next if $item eq '..';

        _idv_visit($top->{$item}, $rtn);

        &$rtn($top, $item);
    }
}

sub idv_set_tree
{
    my $newtree = shift;

    $tree = $newtree;
    $cwd = $tree;

    _idv_visit($tree, \&_idv_add_special);
}

sub idv_clear_tree
{
    _idv_visit($tree, \&_idv_remove_special);
    $tree = {};
    $pwd = '/';
    $cwd = $tree;
}

# sub idv_mkdir
# {
#     my $path = shift;
#     my $dpath;
#     #my $lastdir;

#     $path = File::Spec->canonpath(File::Spec->catdir($pwd, $path));
#     $path =~ s{//+}{/}g;
#     $path =~ s{/$}{};
#     $path =~ s{^/}{};

#     $dpath = $tree;
#     #$lastdir = $dpath;

#     foreach my $dir (File::Spec->splitdir($path))
#     {
#         if (!exists($dpath->{$dir}))
#         {
#             $dpath->{$dir} = {};
#         }

#         #$lastdir = $dpath;
#         $dpath = $dpath->{$dir};
#     }

#     #return $lastdir;
#     return $dpath;
# }

sub idv_is_ref_dir
{
    my $dir = shift;

    #print "isdir Checking $dir, result is \"", ref $dir, "\"\n";
    return ref $dir eq 'HASH';
}

sub idv_test_isdir
{
    my $name = shift;

    my ($status) = _get_dir($name);

    return $status == 0;
}

sub idv_test_isfile
{
    my $name = shift;

    my ($status, $dpath) = _get_dir($name);

    return ($status == 2) && ($dpath eq basename($name));
}

sub idv_test_exists
{
    my $name = shift;

    return (idv_test_isfile($name) || idv_is_ref_dir($name));
}

# Create a directory path from an existing directory.
# The top of $newpath must not already exist.
sub _make_path
{
    my $existing_dir = shift;
    my $newpath = shift;

    foreach my $dir (split('/', $newpath))
    {
        #$existing_dir->{$dir} = {};
        $existing_dir->{$dir}->{'..'} = $existing_dir;
        $existing_dir = $existing_dir->{$dir};
    }

    return $existing_dir;
}

sub idv_mkdir
{
    my $path = shift;
    my $retval;

    $path = File::Spec->canonpath(File::Spec->catdir($pwd, $path));
    $path =~ s{//+}{/}g;

    my ($status, $dpath, $restpath) = _get_dir($path);

    #print STDERR "status is \"$status\"\n";
    if ($status == 0)
    {
        # The directory path already exists
        $retval = $dpath;
    }
    elsif ($status == 1)
    {
        # This is guaranteed to be sucessful
        #print STDERR "restpath is \"$restpath\"\n";
        $retval = _make_path($dpath, $restpath);
    }
    else
    {
        croak "A regular file ($dpath) was found while creating the directory path \"$path\"\n";
    }
}

sub _get_dir
{
    my $path = shift;
    my $status = 0;
    my $dpath;
    my $restpath = '';
    my $dir;

    confess "Undefined path\n" unless defined($path);
    if ($path)
    {
        $path =~ s{//+}{/}g;
        $path =~ s{/$}{};

        if ($path =~ m{^/})
        {
            $dpath = $tree;
        }
        else
        {
            $dpath = $cwd;
        }
    }
    else
    {
        $dpath = $cwd;
        $path = '.';
    }

    my @dirlist = File::Spec->splitdir($path);
    #print STDERR "dirlist is: ", join(':', @dirlist), "\n";
    while (defined($dir = shift @dirlist))
    {
        #print STDERR "Checking \"$dir\", with \"", join(':', @dirlist), "\"\n";
        next if !$dir;

        #print STDERR "1, \"", $dpath->{$dir}, "\"\n";
        if (exists $dpath->{$dir} and idv_is_ref_dir($dpath->{$dir}))
        {
            #print STDERR "2\n";
            $dpath = $dpath->{$dir};
            #print STDERR "dpath is: ", Dumper($dpath);
            $status = 0;
        }
        elsif (exists $dpath->{$dir})
        {
            #print STDERR "3\n";
            $status = 2;
            $dpath = $dir;
            $restpath = join('/', ($dir, @dirlist));
            last;
        }
        else
        {
            #print STDERR "4\n";
            $status = 1;
            #print STDERR Dumper(\@dirlist);
            $restpath = join('/', ($dir, @dirlist));
            #print STDERR "5\n";
            last;
        }
    }

    #print STDERR "6\n";
    return ($status, $dpath, $restpath);
}

# sub idv_getdir
# {
#     my $path = shift;

#     $path =~ s{//+}{/}g;
#     $path =~ s{^/}{};
#     $path =~ s{/$}{};

#     my $dpath = $tree;

#     #print STDERR "For $path, ", Dumper($tree);
#     foreach my $dir (File::Spec->splitdir($path))
#     {
#         if (!exists($dpath->{$dir}))
#         {
#             return undef;
#         }

#         $dpath = $dpath->{$dir};
#         #print STDERR "dpath ($dir)is: ", Dumper($dpath);
#     }

#     return $dpath;
# }

sub idv_add_file
{
    my $path = shift;
    my $filedata = shift;
    my $dpath;

    my ($vol, $dirpath, $filename) = File::Spec->splitpath($path);
    $dirpath =~ s{//+}{/}g;
    $dpath = idv_mkdir($dirpath);

    $dpath->{$filename} = $filedata;
}

sub idv_get_file
{
    my $path = shift;

    my ($vol, $dirpath, $filename) = File::Spec->splitpath($path);
    $dirpath =~ s{//+}{/}g;
    #print STDERR "idv_get_file: vol, dirpath, filename: \"$vol\" \"$dirpath\" \"$filename\"\n";

    croak "File \"$path\" not found\n" unless idv_test_isfile($path);
    my ($status, $dpath) = _get_dir($dirpath);

    return $dpath->{$filename};
}

#
# Given something that looks like a directory tree,
sub idv_convert_to_tree
{

}

1;
