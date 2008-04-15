#
# Provides an interface to the file system. We will use either
# this module or FileString.pm (for testing).
#
# For convenience in programming, this module works just like
# IO::File, with some additions.
#
package Idval::FileSystem;
use strict;
use warnings;
use Carp;
use IO::File;
use File::Glob ':glob';
use File::Find;
use File::Path;

use base qw(IO::File);

# This seems to be needed for AUTOLOAD to work
sub new
{
    # Special cases; so we can use 3-argument form, mostly
    if (($#_ == 2) and ($_[1] eq '-') and ($_[2] eq '>'))
    {
        return IO::File::new($_[0], '>-');
    }
    # Special cases; so we can use 3-argument form, mostly
    elsif (($#_ == 2) and ($_[1] eq '-') and ($_[2] eq '<'))
    {
        return IO::File::new($_[0], '-');
    }
    else
    {
        return IO::File::new(@_);
    }
}

sub idv_find
{
    my $subr = shift;
    return File::Find::find({wanted => $subr, preprocess => sub{return grep(-r, @_);}}, @_);
}

sub idv_glob
{
    return File::Glob::bsd_glob(@_);
}

sub idv_mkdir
{
    my $path = shift;

    my @dirs = File::Path::mkpath($path);

    return scalar @dirs;
}

sub idv_test_exists
{
    my $filename = shift;

    return -e $filename;
}

sub idv_test_isdir
{
    my $filename = shift;

    return -d $filename;
}

sub idv_test_isfile
{
    my $filename = shift;

    return -f $filename;
}

1;
