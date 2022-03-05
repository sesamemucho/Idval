package Idval::Plugins::Command::Sync;

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
use File::Spec;
use File::stat;
use File::Basename;
use File::Temp qw/ tempfile /;
use Time::HiRes qw(gettimeofday tv_interval);
use Getopt::Long;
use English '-no_match_vars';;
use Memoize;
use Storable;

use Idval::I18N;
use Idval::Logger qw(idv_print info_q verbose chatty idv_dbg);
use Idval::Common;
use Idval::FileIO;
use Idval::DoDots;

my $first = 1;

my $progress_data = {};
my %prov_list;
my %keynames;

my $lh;
my $no_run;

my @sync_options_in =
    (
     'mp3',
     'ogg',
     'block=s',
     'no_run',
    );

my %options_in = 
    (
     'mp3' => 0,
     'ogg' => 0,
     'no_run' => 0,
    );

memoize('get_file_ext');
memoize('get_all_extensions_regexp');
memoize('get_converter');

sub init
{
    %prov_list = ();
    $lh = Idval::I18N->idv_get_handle() || die "Can't get language handle.";

    foreach my $name (qw(sync convert filter transcode remote_top sync_dest))
    {
        $keynames{$name} = $lh->idv_getkey('sync_cmd', $name);
    }

    $no_run = 0;

    return;
}

sub main
{
    my $datastore = shift;
    my $providers = shift;
    my @args = @_;
    my $status;

    #Idval::Common::get_logger()->str("sync");
    #$Devel::Trace::TRACE = 1;
    # Storable::dclone doesn't work with regexps
    # Make a copy of the config, to restore it at the end of the
    # command.  In particular, any filter converters will need access
    # to the sync data.
    my $config = Idval::Common::get_common_object('config');
    my $old_config = $config->copy();
    $Devel::Trace::TRACE = 0;

    my $typemap = Idval::Common::get_common_object('typemap');
    my $dotmap = $typemap->get_dot_map();
    Idval::DoDots::init();

    my ($syncfile, $should_delete_syncfile) = _parse_args(@args);

    # Now, make a new config object that incorporates the sync file info.
    $config->add_file($syncfile);
    #print STDERR "Sync: config is: ", Dumper($config);
    progress_init($progress_data, $datastore);

    my %records_to_process;

    # To save time, don't go through Idval::Config::i18n_* routines
    #my $keyname_sync =
    #print STDERR "sync: datastore is: ", Dumper($datastore);
    foreach my $key (sort keys %{$datastore->{RECORDS}})
    {
        chatty("checking file \"$key\"\n");
        my $tag_record = $datastore->{RECORDS}->{$key};
        my $do_sync = $config->get_single_value($keynames{'sync'}, $tag_record);    # Already I18N'd
        if ($do_sync)
        {
            progress_inc_number_to_process($progress_data);
            $records_to_process{$key} = 1;
        }
    }

    progress_print_title($progress_data);

    foreach my $key (sort keys %records_to_process)
    {
        $status = each_item($datastore->{RECORDS}, $key, $config);

        if ($status != 0)
        {
            last;
        }
    }

    unlink $syncfile if $should_delete_syncfile;

    map { $_->close() } values %prov_list;

    info_q("[quant,_1,record,records] successfully processed\n", scalar(keys(%records_to_process)));

    Idval::Common::register_common_object('config', $old_config);
    return $datastore;
}

sub ok_to_convert
{
    my $local_pathname = shift;
    my $remote_pathname = shift;

    my $convert_file = 0;
    my $l_st = stat($local_pathname);
    my $r_st = stat($remote_pathname);

    if (not -e $remote_pathname) {
        $convert_file = 1;
        verbose("Remote file \"[_1]\" does not exist. Will create.\n", $remote_pathname);
    } elsif ($r_st->mtime < $l_st->mtime) {
        $convert_file = 1;
        verbose("Remote file \"[_1]\" is older than local file \"[_2]\". Will convert.\n", $remote_pathname, $local_pathname);
    } else {
        $convert_file = 0;
        verbose("Remote file \"[_1]\" is newer than local file \"[_2]\". Will not convert.\n", $remote_pathname, $local_pathname);
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

    my $tag_record = $hash->{$key};
    my $retval = 0;

    my $do_sync = $config->get_single_value($keynames{'sync'}, $tag_record);    # Already I18N'd

    progress_inc_seen($progress_data);

    print STDERR "Checking", $tag_record->get_name(), "\n";
    idv_dbg("Checking [_1]\n", $tag_record->get_name());
    if (! $do_sync)
    {
        return $retval;
    }

    my $src_type = $tag_record->get_value('TYPE');
    my $dest_type = $config->get_single_value($keynames{'convert'}, $tag_record);    # Already I18N'd
    my $prov;

    my $filters = $config->get_list_value($keynames{'filter'}, $tag_record);    # Already I18N'd
    my $transcode = $config->get_single_value($keynames{'transcode'}, $tag_record);    # Already I18N'd
    my @attributes;
    my @attrnames;
    foreach my $filter (@{$filters})
    {
        next unless $filter;
        printf STDERR "SYNC: filter is <$filter>\n";
        push(@attributes, 'filter:' . $filter);
        push(@attrnames, $keynames{'filter'} . ':' . $filter);
    }
    if ($transcode)
    {
        push(@attributes, 'transcode');
        push(@attrnames, $keynames{'transcode'});
    }

    chatty("source type is \"[_1]\" dest type is \"[_2]\"; [quant,_3,Attribute was found:,Attributes were found:] [_4]\n",
           $src_type, $dest_type, scalar(@attrnames), join(' ', @attrnames));

    $prov = get_converter($src_type, $dest_type, @attributes);
# Should be taken care of by ProviderMgr now
#     if (!$prov && ($src_type eq $dest_type))
#     {
#         # Don't get excited. The '*' is just a label. No globbing is involved.
#         $prov = get_converter('*', '*');
#     }

    chatty("src: [_1] to dest: [_2] yields converter [_3]\n", $src_type, $dest_type, $prov->query('name'));

    # Keep track of all the providers, so we can call close() on them later.
    $prov_list{$prov} = $prov;

    my ($src_path, $dest_path) = get_file_paths($tag_record, $dest_type, $prov, $config);

    if (ok_to_convert($src_path, $dest_path))
    {

        chatty("Converting \"[_1]\" to \"[_2]\"\n", $src_path, $dest_path);
        my $dest_dir = dirname($dest_path);
        if (!Idval::FileIO::idv_test_isdir($dest_dir))
        {
            Idval::FileIO::idv_mkdir($dest_dir);
        }

        # Save the destination path back into the tag record.
        # This tag (since it begins with '__') will not be saved.
        $tag_record->add_tag('__DEST_PATH', $dest_path);

        #print STDERR "tag_record: ", Dumper($tag_record);
        if ($no_run)
        {
            idv_print("Not converting \"[_1]\" to \"[_2]\"\n", $src_path, $dest_path);
        }
        else
        {
            $retval = $prov->convert($tag_record, $dest_path, $config);
        }
        $retval = 0;

        progress_print_line($progress_data);
    }
    else
    {
        chatty("Did not convert \"[_1]\" to \"[_2]\"\n", $src_path, $dest_path);
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
    idv_dbg("Getting provider for src:[_1] dest:[_2]\n", $src_type, $dest_type);
    return $providers->get_provider('converts', $src_type, $dest_type, @_);
}

sub _parse_args
{
    my @args = @_;

    my $orig_args = join(' ', @args);
    my $mp3 = 0;
    my $ogg = 0;
    my @blocks = ();

    $no_run = 0;                # Make sure it's zeroed each time 'sync' is called

    {
        # We need to do our own argument parsing
        local @ARGV = @args;

        print STDERR "sync_options_in: ", Dumper(\@sync_options_in);
        print STDERR "options_in: ", Dumper(\%options_in);
        my ($option_names, $option_list, $option_hash) = 
            $lh->idv_translate_options(\@sync_options_in, \%options_in);

        print STDERR "option_names: ", Dumper($option_names);
        print STDERR "option_list: ", Dumper($option_list);
        print STDERR "option_hash: ", Dumper($option_hash);

        my $opts = Getopt::Long::Parser->new();
        my $retval = $opts->getoptions($option_hash, @{$option_list});

        @blocks = $option_hash->{$option_names->{'block'}} if defined($option_names->{'block'});
        $mp3    = $option_hash->{$option_names->{'mp3'}};
        $ogg    = $option_hash->{$option_names->{'ogg'}};
        $no_run = $option_hash->{$option_names->{'no_run'}};

        @args = (@ARGV);
    }

    if ((scalar @args == 0) && (scalar @blocks == 0))
    {
        Idval::Common::get_logger()->fatal("Sync: Need at least one argument to sync\n");
        # Should print out Synopsis here
    }
    elsif (scalar @args == 1)
    {
        return ($args[0], 0);
    }
    elsif (scalar @args == 2)
    {
        $blocks[0] = $args[0] . ':' . $args[1];
    }
    elsif (scalar @blocks == 0)
    {
        # We're going to need a Help module...
        Idval::Common::get_logger()->fatal("Sync: Need at least one argument to sync\n");
        # Should print out Synopsis here
    }

    # Else, assume it's src/dest specs

    my $convert_type = $ogg            ? 'OGG'
                     : $mp3            ? 'MP3'
                     : 'MP3';

    my $syncfile = "{\n";
    foreach my $blockspec (@blocks)
    {
        my ($selectors, $remote_top) = split(/:/, $blockspec);
        if (!(defined($selectors) && defined($remote_top)))
        {
            Idval::Common::get_logger()->fatal("Sync: argument error ($orig_args)\n");
            # Should print out Synopsis here
        }

        $syncfile .= "convert    = $convert_type\n";

        $syncfile .= "}\n{\n";
        $syncfile .= "\tremote_top = $remote_top\n";
        foreach my $src (split(/;/, $selectors))
        {
            # A src argument that is just a file name is assumed to be a FILE parameter

            if (-e $src)
            {
                $syncfile .= "\tFILE has $src\n";
            }
            else
            {
                $syncfile .= "\t$src\n";
            }
        }

        $syncfile .= "\tsync=1\n}\n\n";
    }

    # Write it to temp file...
    my ($fh, $filename) = tempfile();

    print $fh $syncfile;
    $fh->close();

    return $filename;
}

sub progress_init
{
    my $this = shift;
    my $datastore = shift;

    $this->{total_number_to_process} = 0;
    $this->{number_of_seen_records} = 0;
    $this->{number_of_processed_records} = 0;
    $this->{total_number_of_records} = scalar(keys %{$datastore->{RECORDS}});

    $this->{start_time} = [gettimeofday];
    return;
}

sub progress_inc_seen
{
    my $this = shift;

    $this->{number_of_seen_records}++;
    return;
}

sub progress_inc_number_to_process
{
    my $this = shift;

    $this->{total_number_to_process}++;
    return;
}

sub progress_print_title
{
    my $this = shift;

    info_q("processed remaining  total  percent  elapsed  remaining    total\n");
    info_q("[sprintf,%5d %9d %9d %5.0f%%     %8s  %8s  %8s,_1,_2,_3,_4,_5,_6,_7]\n",
                    0,
                    $this->{total_number_to_process},
                    $this->{total_number_to_process},
                    0.0,
                    '00:00:00',
                    '00:00:00',
                    '',
            );
    return;
}

sub progress_print_line
{
    my $this = shift;

    $this->{number_of_processed_records}++;
    my $fraction = ($this->{number_of_processed_records} / $this->{total_number_to_process});

    my $safe_frac = $fraction < 0.001 ? 0.001 : $fraction;

    my $elapsed_time = tv_interval($this->{start_time});

    my $est_time = $elapsed_time / $safe_frac;
    my $est_time_remaining = $est_time - $elapsed_time;

    info_q("[sprintf,%5d %9d %9d %5.0f%%     %8s  %8s  %8s,_1,_2,_3,_4,_5,_6,_7]\n",
                     $this->{number_of_processed_records},
                     $this->{total_number_to_process} - $this->{number_of_processed_records},
                     $this->{total_number_to_process},
                     $fraction  * 100.0,
                     progress_format_time($elapsed_time),
                     progress_format_time($est_time_remaining),
                     progress_format_time($est_time),
           );
    return;
}

sub progress_format_time
{
    my $fsec = shift;

    my $sec = int($fsec);
    $sec = 0 if $sec < 0;

    my $hrs = int($sec / 3600);
    my $mins = int(int ($sec - int ($hrs * 3600)) / 60);
    my $secs = $sec % 60;
    my $minspec;

    if ($hrs != 0)
    {
        $hrs = sprintf("%2d:", $hrs);
        $mins = ($mins != 0) ? sprintf("%02d", $mins) : '  ';
    }
    else
    {
        $hrs = '   ';
        $mins = ($mins != 0) ? sprintf("%2d", $mins) : '  ';
    }
    $secs = sprintf(":%02d", $secs);

    return $hrs . $mins . $secs;
}

sub get_file_paths
{
    my $tag_record = shift;
    my $dest_type = shift;
    my $prov = shift;
    my $config = shift;

    my $src_path = $prov->get_source_filepath($tag_record);
    my ($volume, $src_dir, $src_name) = File::Spec->splitpath($src_path);
    chatty("For [_1]\n", $src_path);
    my $remote_top = Idval::Common::mung_to_unix($config->get_single_value($keynames{'remote_top'}, $tag_record));    # Already I18N'd
    chatty("   remote top is \"[_1]\"\n", $remote_top);
    my $dest_name = $prov->get_dest_filename($tag_record, $src_name, get_file_ext($dest_type));
    chatty("   dest name is \"[_1]\" ([_2])\n", $dest_name, $prov->query('name'));
    my $sync_dest = Idval::Common::mung_to_unix($config->get_single_value($keynames{'sync_dest'}, $tag_record));    # Already I18N'd

    my $extre = get_all_extensions_regexp();
    if ($sync_dest !~ m/$extre/)
    {
        # sync_dest is a directory, so to get the destination name just append dest_name
        $sync_dest = File::Spec->catfile($sync_dest, $dest_name);
        chatty("sync_dest is a directory: sync dest is \"[_1]\"\n", $sync_dest);
    }

    my $dest_path = File::Spec->catfile($remote_top, $sync_dest);
    $dest_path = Idval::Common::mung_to_unix($dest_path);

    if ($dest_path =~ m{%LASTDIR%})
    {
        my $lastdir = (File::Spec->splitdir(File::Spec->canonpath($src_dir)))[-1];
        $dest_path =~ s{%LASTDIR%}{$lastdir};
    }

    # Do we have any tagname expansions?
    if (my @tags = ($dest_path =~ m/%([^%]+)%/g))
    {
        idv_dbg("Found tags to expand: [_1]\n", join(',', @tags));
        foreach my $tag (@tags)
        {
            $dest_path =~ s{%$tag%}{$tag_record->{$tag}} if exists($tag_record->{$tag});
        }
        idv_dbg("dest path is now: \"[_1]\"\n", $dest_path);
    }

    $dest_path = File::Spec->canonpath($dest_path); # Make sure the destination path is nice and clean

    return ($src_path, $dest_path);
}

=pod

=head1 NAME

X<sync>sync - Synchronizes a destination tree with the current taglist

=head1 SYNOPSIS

sync syncfile

=head1 DESCRIPTION

B<sync> synchronizes a destination tree with the current taglist
    according to a supplied F<syncfile>. As it runs, it prints out
    messages that indicate progress.

    For each file that was synced, B<sync> adds the tag C<__DEST_PATH>
    to the record in the current taglist. This tag contains the full
    pathname of the destination of the synchronized file.

    F<syncfile> is an Idval config file (See L<idv/"Configuration
    files"> for a description of config files). It must define the
    following variables:

=over 4

=item sync

This indicates whether or not something should be synchronized. It
    should be either present and set to 1, or not present at all. For
    instance, the following fragment will cause all files that have
    'hurk' in the title to be synchronized:

    {
       TIT2 has hurk
       sync = 1
    }

=item X<convert>convert

This indicates the type of the destination file. Source files that are
    synchronized will be converted into this type of file. For music
    files, the system default convertion type is OGG. This should be
    changed, if desired, in the user's local configuration file (see
    L<idv/"First time configuration">). It can, of course, be changed
    in the syncfile.

=item X<remote_top>remote_top

This is a directory name that points to the top of where you want the
    synchronized files to go. If, for instance, your music player
    mounts as F</media/IAUDIO>, you might want B<remote_top> to be
    F</media/IAUDIO/Music>.

=item X<sync_dest>sync_dest

This lets you have a little more control of where synchronized files
    go.

=over 4

=item 1

If sync_dest is set and looks like a file, the destination path is:
    $remote_top/$sync_dest. Example:

    remote_top = /media/IAUDIO/Music
    sync_dest  = weary.ogg

Any music file synchronized with these values would go into
    /media/IAUDIO/Music/weary.ogg. Naturally, you wouldn't want these
    values to apply to more than one file at a time, since all files
    except for the last would get overwritten.

=item 2

If sync_dest is set and looks like a directory, the destination path is:
    $remote_top/$sync_dest/$source_name.<conversion_extension>. Example:

    remote_top = /media/IAUDIO/Music
    sync_dest  = sad_songs/children

Any music file synchronized with these values would go into
    /media/IAUDIO/Music/sad_songs/children, for instance, the song
    /mystuff/cd/monroe/little_girl_and_the_dreadful_snake.flac would get
    sent to:

    /media/IAUDIO/Music/sad_songs/children/little_girl_and_the_dreadful_snake.ogg

Note that if sync_dest is not set, it's the same as if it were set to
nothing:

    remote_top = /media/IAUDIO/Music
    sync_dest  =

would cause files to go into /media/IAUDIO/Music/.

=back

In addition, both C<remote_dir> and C<sync_dest> may have special
    strings inside them that cause interesting things to happen.

=over

=item %LASTDIR%

The string C<%LASTDIR%> will be replaced by the name of the directory
    that contains the source file. For example, with

    remote_top = /media/IAUDIO/Music
    sync_dest  = sad_songs/children/%LASTDIR%

the song /mystuff/cd/monroe/little_girl_and_the_dreadful_snake.flac
    would get sent to:

    /media/IAUDIO/Music/sad_songs/children/monroe/little_girl_and_the_dreadful_snake.ogg

=item %tagname%

Any string C<%tagname%>, where C<tagname> is the name of one of the
   tags in the tag record. For instance, given the following record:

    FILE = /bgb/bluegrass/stanbro1956-08-05.flac16/stanbro1956-08-05t10.flac
    TALB = 08/05/56 Silver Creek Ranch Paris, VA
    TPE1 = Stanley Brothers
    TYER = 1956
    TCON = Folk
    TIT3 = Silver Creek Ranch Paris, VA
    TIT2 = The Little Girl and the Dreadful Snake
    TRCK = 10

with

    remote_top = /media/IAUDIO/Music
    sync_dest  = sad_songs/%TCON%/%TPE1%/%TYER%

the song would get sent to:

    /media/IAUDIO/Music/sad_songs/Folk/Stanley Brothers/1956/stanbro1956-08-05t10.ogg

=back

=back

=head2 Other settings

B<Sync> can call in other functionality when synchronizing files. The two that are currently defined are B<filter> and B<transcode>. Both B<filter> and B<transcode> change files as they are synchronized. B<Filters> affect all transformations in a given class (for instance, all MUSIC files), and B<transcoders> only affect one (or some subset) of files.

=over 4

=item X<filter>B<Filter>

To invoke a filter, set the variable C<filter> to the name of the desired idv filter.

    {
    ...
    filter = sox
    ...
    }

=over 4

=item sox

B<Sox> is a powerful sound processor that can be used in any music
file conversion. See L<sox> for information on the idv filter, and
L<http:///sox.sourceforge.net/> for information about the B<sox>
program.

Control this filter with the C<sox_args> variable. The value of this
variable should be the desired command-line arguments to the B<sox>
program, with two changes: the input file is represented by %INFILE%
and the output file is represented by %OUTFILE% (See L<sox> for
examples).


=back

=item X<transcode>B<Transcode>

Put transcode information here. XXX

=back



=cut

1;
