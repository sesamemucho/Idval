package Idval::UserPlugins::Sync;

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

use Data::Dumper;
use File::Spec;
use File::stat;
use File::Basename;
use English;
use Carp;
use Memoize;
use Storable;

use Idval::Constants;
use Idval::Common;
use Idval::FileIO;
use Idval::DoDots;

our $first = 1;
our $total_number_of_records;
our $total_number_to_process;
our $number_of_seen_records;
our $number_of_processed_records;


memoize('get_file_ext');
memoize('get_all_extensions_regexp');
memoize('get_converter');

sub init
{
    *verbose = Idval::Common::make_custom_logger({level => $VERBOSE,
                                                  debugmask => $DBG_PROCESS,
                                                  decorate => 1});

    *progress = Idval::Common::make_custom_logger({level => $INFO,
                                                  debugmask => $DBG_PROCESS,
                                                  decorate => 0});

    set_pod_input();
}

sub sync
{
    my $datastore = shift;
    my $providers = shift;
    my @args = @_;
    my $status;

    # We want to add to the config object, but not pollute it for those who follow
    # Storable::dclone doesn't work with regexps
    my $config = Idval::Common::deep_copy(Idval::Common::get_common_object('config'));

    my $typemap = Idval::Common::get_common_object('typemap');
    my $dotmap = $typemap->get_dot_map();
    Idval::DoDots::init();

    my $syncfile = defined($args[0]) ? $args[0] : '';
    croak "Need a sync file." unless $syncfile;
    # Now, make a new config object that incorporates the sync file info.
    $config->add_file($syncfile);

    $total_number_to_process = 0;
    $number_of_seen_records = 0;
    $number_of_processed_records = 0;
    $total_number_of_records = scalar(keys %{$datastore->{RECORDS}});

    foreach my $key (sort keys %{$datastore->{RECORDS}})
    {
        my $record = $datastore->{RECORDS}->{$key};
        my $sync_dest = $config->get_single_value('sync_dest', $record);
        my $do_sync = $config->get_single_value('sync', $record);
        if ($sync_dest and $do_sync)
        {
            $total_number_to_process++;
        }
    }

    progress(sprintf("%6d %6d %6d %2.0f%%\n",
                     0,
                     $total_number_to_process,
                     $total_number_to_process,
                     0.0));

    foreach my $key (sort keys %{$datastore->{RECORDS}})
    {
        $status = each_item($datastore->{RECORDS}, $key, $config);

        if ($status != 0)
        {
            last;
        }
    }

    return $datastore;
}

sub ok_to_convert
{
    my $local_pathname = shift;
    my $remote_pathname = shift;

    #$log->log_error('Idval::CannotReadFile', $local_pathname) unless -r "$local_pathname";

    my $convert_file = 0;
    my $l_st = stat($local_pathname);
    my $r_st = stat($remote_pathname);

    if (not -e $remote_pathname) {
        $convert_file = 1;
        #$log->verbose("Remote file \"$remote_pathname\" does not exist. Will create.\n");
    } elsif ($r_st->mtime < $l_st->mtime) {
        $convert_file = 1;
        #$log->verbose("Remote file \"$remote_pathname\" is older than local file \"$local_pathname\". Will convert.\n");
    } else {
        $convert_file = 0;
        #$log->verbose("Remote file \"$remote_pathname\" is newer than local file \"$local_pathname\". Will not convert.\n");
    }

    return $convert_file;
}

# If sync_dest is set and looks like a file, the destination path is: $remote_top/$sync_dest
# If sync_dest is set and looks like a directory, the destination path is:
#                      $remote_top/$sync_dest/$source_name.<conversion_extension>
# If sync_dest is not set and do_sync is set, the destination path is:
#                      $remote_top/$source_name.<conversion_extension>
#   Note that is is the same as if sync_dest = ''


#
# if $remote_top/$sync_dest contains the string %LASTDIR%, this string will be replaced by
#    the name of the parent directory of the file indicated by $src_name
#
# $remote_top is a directory path. It may be empty.
# $sync_dir is the directory part of $sync_dest. If $sync_dest appears to be a directory, then
#     $sync_dir = $sync_dest
# $sync_name is the filename part of $sync_dest. If $sync_dest appears to be a directory, then
#     $sync_name = ''
#
# $src_path is the full pathname of the source file.
# $src_dir  is the directory part of $src_path
# $src_name is the filename part of $src_path
# $src_ext  is the extension of $src_name

# $dest_path is the full pathname of the destination file, =
#   $dest_dir + $dest_name + $dest_ext

sub each_item
{
    my $hash = shift;
    my $key = shift;
    my $config = shift;

    my $record = $hash->{$key};
    my $retval = 0;

    if ($first and ($key =~ m/ogg/))
    {
        #print STDERR "Record is: ", Dumper($record);
        #print STDERR Dumper($config);
        $first = 0;
    }

    my $sync_dest = Idval::Common::mung_to_unix($config->get_single_value('sync_dest', $record));
    my $do_sync = $config->get_single_value('sync', $record);
#     if ($sync_dest or $do_sync)
#     {
#         print STDERR "sync_dest = \"$sync_dest\", do_sync = \"$do_sync\"\n";
#     }

    $number_of_seen_records++;

    if (! $do_sync)
    {
        return $retval;
    }

    my $src_type = $record->get_value('TYPE');
    my $dest_type = $config->get_single_value('convert', $record);
    my $prov = get_converter($src_type, $dest_type);


    my $src_path = $prov->get_source_filepath($record);
    my ($volume, $src_dir, $src_name) = File::Spec->splitpath($src_path);
    #print STDERR "For $src_path\n";
    my $remote_top = Idval::Common::mung_to_unix($config->get_single_value('remote_top', $record));
    #print STDERR "   remote top is \"$remote_top\"\n";
    my $dest_name = $prov->get_dest_filename($record, $src_name, get_file_ext($dest_type));



#     my $src_path =  $record->get_name();
#     my ($volume, $src_dir, $src_name) = File::Spec->splitpath($src_path);
#     #print STDERR "For $src_path\n";
#     my $remote_top = Idval::Common::mung_to_unix($config->get_single_value('remote_top', $record));
#     #print STDERR "   remote top is \"$remote_top\"\n";
#     my $src_type = $record->get_value('TYPE');
#     my $dest_type = $config->get_single_value('convert', $record);

#     my $dest_name;
#     my $dest_ext = get_file_ext($dest_type);
#     ($dest_name = $src_name) =~ s{\.[^.]+$}{.$dest_ext};

    my $extre = get_all_extensions_regexp();
    if ($sync_dest !~ m/$extre/)
    {
        #print STDERR "sync_dest is a directory\n";
        # sync_dest is a directory, so to get the destination name just append dest_name
        $sync_dest = File::Spec->catfile($sync_dest, $dest_name);
    }

    my $dest_path = File::Spec->catfile($remote_top, $sync_dest);
    $dest_path = Idval::Common::mung_to_unix($dest_path);

    if ($dest_path =~ m{%LASTDIR%})
    {
        my $lastdir = (File::Spec->splitdir(File::Spec->canonpath($src_dir)))[-1];
        $dest_path =~ s{%LASTDIR%}{$lastdir};
    }

    $dest_path = File::Spec->canonpath($dest_path); # Make sure the destination path is nice and clean

    if (ok_to_convert($src_path, $dest_path))
    {
        $number_of_processed_records++;

        #print STDERR "Converting \"$src_path\" to \"$dest_path\"\n";
        my $dest_dir = dirname($dest_path);
        if (!Idval::FileIO::idv_test_isdir($dest_dir))
        {
            Idval::FileIO::idv_mkdir($dest_dir);
        }

        $retval = $prov->convert($record, $dest_path);
        $retval = 0;

        progress(sprintf("%6d %6d %6d %2.0f%%\n",
                         $number_of_processed_records,
                         $total_number_to_process - $number_of_processed_records,
                         $total_number_to_process,
                         ($number_of_processed_records / $total_number_to_process) * 100.0));
    }
    else
    {
        print STDERR "Did not convert \"$src_path\" to \"$dest_path\"\n";
        $retval = 0;
    }

    return $retval;
}

sub epilog
{
}

sub get_file_ext
{
    my $typemap = Idval::Common::get_common_object('typemap');
    my $type = shift;

    return $typemap->get_output_ext_from_filetype($type);
}

sub get_all_extensions_regexp
{
    my $typemap = Idval::Common::get_common_object('typemap');

    my @exts = $typemap->get_all_extensions();
    my $restring = '\.(' . join('|', @exts) . ')';
    my $re = qr{$restring};

    return $re;
}

sub get_converter
{
    my $providers = Idval::Common::get_common_object('providers');

    my $src_type = shift;
    my $dest_type = shift;

    return $providers->get_provider('converts', $src_type, $dest_type);
}

sub set_pod_input
{
    my $help_file = Idval::Common::get_common_object('help_file');

    my $pod_input =<<EOD;

=head1 NAME

sync - Synchronizes a remote directory to the local directory

=head1 SYNOPSIS

sync sync-data-file

sync-data-file is a cascading configuration file that tells the program which files to synchronize
and how to do it.

=head1 OPTIONS

This command has no options.

=head1 DESCRIPTION

B<This program> will read the given input file(s) and do something
useful with the contents thereof.

=cut

EOD
    $help_file->{'sync'} = $pod_input;
}

1;
