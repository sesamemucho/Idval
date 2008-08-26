package Idval::Ui;

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
use Carp;
use Storable;
use Config;
use English '-no_match_vars';
use File::Basename;
use File::Path;
use File::Spec;

use Idval::Common;
use Idval::Config;
use Idval::FileIO;
use Idval::TypeMap;
use Idval::Collection;
use Idval::Record;
use Idval::DataFile;
use Idval::DoDots;

my $srclist;

sub get_sysconfig_file
{
    my $datadir = shift;
    my $cfgname = '';

    if (Idval::FileIO::idv_test_exists("$datadir/idval.xml"))
    {
        $cfgname = "$datadir/idval.xml";
    }
    elsif (Idval::FileIO::idv_test_exists("$datadir/idval.cfg"))
    {
        $cfgname = "$datadir/idval.cfg";
    }
    else
    {
        croak "No idval configuration file found in \"$datadir\"\n";
    }

    return $cfgname;
}

sub get_userconfig_file
{
    my $datadir = shift;
    my $osname = $Config{'osname'};
    my $cfgname = '';

    if (exists($ENV{HOME}) and Idval::FileIO::idv_test_exists("$ENV{HOME}/.idvalrc"))
    {
        $cfgname = "$ENV{HOME}/.idvalrc";
    }
    elsif ($osname eq 'MSWin32')
    {
        $cfgname = "idvaluser.cfg" if Idval::FileIO::idv_test_exists("idvaluser.cfg");
        $cfgname = "$datadir/idvaluser.cfg" if Idval::FileIO::idv_test_exists("$datadir/idvaluser.cfg");
    }
    elsif ($osname =~ m/ux$/ix or $osname =~ m/cygwin/ix)
    {
        $cfgname = '.idvalrc' if Idval::FileIO::idv_test_exists('.idvalrc');
        $cfgname = "$datadir/idvaluser.cfg" if Idval::FileIO::idv_test_exists("$datadir/idvaluser.cfg");
    }
    else
    {
        $cfgname = "$datadir/idvaluser.cfg" if Idval::FileIO::idv_test_exists("$datadir/idvaluser.cfg");
        $cfgname = 'data/idvaluser.cfg' if Idval::FileIO::idv_test_exists('data/idvaluser.cfg');
    }

    print "user config file name is: \"$cfgname\"\n";
    return $cfgname;
}

# Do a path search for the specified command file
# Allow a default file extension of .idv
sub find_command_file
{
    my $config = shift;
    my $cmd_name = shift;
    my $command_file = '';
    my $dirlist = $config->get_list_value('command_dir');

    if ($cmd_name)
    {
        if ($cmd_name !~ m{\.[^.]+$}x)
        {
            $cmd_name .= '.idv';
        }

        foreach my $dir (@{$dirlist})
        {
            my $cmd = File::Spec->catfile($dir, $cmd_name);
            if (Idval::FileIO::idv_test_exists($cmd))
            {
                $command_file = $cmd;
                last;
            }
        }
    }

    return $command_file;
}
sub make_wanted
{
    my $providers = shift;
    my $config = shift;

    my $typemap = Idval::TypeMap->new($providers);
    my %type_list;
    my %record_creators;

    ###Handle sub-types here: so far the only one is MP3 IDV1 or V2 or ???
    ###@type_list should only have extensions
    ###record_creators needs to deal with sub-types

    # Get a list of all the kinds of files we can read with the currently installed
    # 'reads_tags' providers.
    foreach my $item ($providers->_get_providers('reads_tags'))
    {
        # This perly expression will create one entry in the hash %type_list for
        # each extension associated with the filetype handled by this tag reader.
        my $type = $item->get_source();
        @type_list{$typemap->get_exts_from_filetype($type)} = undef;
        $record_creators{$type} = $item;
    }
    
    my @exts = map { '\.' . lc($_) } keys %type_list;

    #print STDERR "exts: ", join(",", @exts), ">\n";
    return sub {
        return if -d $_;
#         my $rec;
        #my($filename, $junk, $suffix) = fileparse($_, @exts);
        my($filename, $junk, $suffix) = fileparse(basename($_), @exts);
        #print STDERR "name is $_, Suffix is: <$suffix>\n";
        return unless $suffix;  # It wasn't one of the ones we were looking for

        $suffix = substr($suffix, 1); # Remove the '.'
        my($class, $type) = $typemap->get_class_and_type_from_ext($suffix);

        my $obj = $record_creators{$type};

        $obj->create_records({filename => $_,
                              path     => $File::Find::name,
                              class    => $class,
                              type     => $type,
                              srclist  => $srclist});
    };
}

# This should just provide a very basic list of records, consisting only of FILE, TYPE and CLASS tags
sub get_source_from_dirs
{
    my $providers = shift;
    my $config = shift;
    my @dirs = map {Idval::Common::expand_tilde($_) }  @_;

    #local $srclist = {};
    $srclist = Idval::Collection->new({source => 'STORED DATA CACHE'});
    my $wanted = make_wanted($providers, $config);

    Idval::FileIO::idv_find($wanted, @dirs);

    #print "srclist: ", Dumper($srclist);
    return $srclist;
}

# Given the name of a data file (which may be blank), and the name of the
# default data store file, return a list of records.

sub get_source_from_file
{
    my $dat_file = shift;
    my $data_store = shift;
    my $reclist;

    if ($dat_file)
    {
        my $dat = Idval::DataFile->new($dat_file);
        $reclist = $dat->get_reclist();
        return $reclist;
    }
    elsif ($data_store)
    {
        $reclist = eval {retrieve(Idval::Common::expand_tilde($data_store))};
        croak "Tag info cache is corrupted; you will need to regenerate it (with 'gettags'):\n$@\n" if $@;
        #print Dumper($reclist);
        return Idval::Collection->new({contents => $reclist});
    }
    else
    {
        croak "No data source specified.";
    }
}

sub put_source_to_file
{
    my $argref = shift;

    my $datastore  = $argref->{datastore};
    my $reclist    = $datastore->{RECORDS};
    my $source_name = $datastore->{SOURCE};
    my $data_store_file = $argref->{datastore_file};

    my $dat_file   = exists $argref->{outputfile} ? $argref->{outputfile} : '';
    my $usecache   = exists $argref->{usecache} ? $argref->{usecache} : 1;

    # First (unless specifically told not to), opaquely to the data store
    if ($usecache)
    {
        # Make sure the path exists
        my $path = dirname(Idval::Common::expand_tilde($data_store_file));
        mkpath($path) unless -d $path;
        #print "Storing data to ",  Idval::Common::expand_tilde($data_store_file), "\n";
        #store($reclist, Idval::Common::expand_tilde($data_store_file));
        store($datastore, Idval::Common::expand_tilde($data_store_file));
        #print "Finished storing data\n";
    }

    # Next, write to output file if requested
    if ($dat_file)
    {
        my $fname = $dat_file;
        my $out = Idval::FileIO->new($fname, '>:utf8') or croak "Can't open $fname for writing: $ERRNO\n";

        print $out join("\n", @{$datastore->stringify()});
        $out->close();
    }

    return;
}

# Given two record lists (Idval::Collection) or two records (Idval::Record) (a & b),
# return three hash refs:
# all items in a that are not in b
# all items common to a and b
# all items in b that are not in a
sub get_rec_diffs
{
    my $rec_a = shift;
    my $rec_b = shift;

    my %a_not_b;
    my %a_and_b;
    my %b_not_a;

    foreach my $item ($rec_a->get_all_keys())
    {
        if ($rec_b->key_exists($item))
        {
            $a_and_b{$item} = $rec_a->get_value($item);
        }
        else
        {
            $a_not_b{$item} = $rec_a->get_value($item);
        }
    }

    foreach my $item ($rec_b->get_all_keys())
    {
        if (! $rec_a->key_exists($item))
        {
            $b_not_a{$item} = $rec_b->get_value($item);
        }
    }

    return (\%a_not_b, \%a_and_b, \%b_not_a);
}

1;
