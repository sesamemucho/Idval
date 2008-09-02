package AcceptUtils;

use strict;
use warnings;

use Data::Dumper;
use Carp;
use IO::File;
use File::stat;
use File::Copy;
use File::Path;
use File::Basename;
use File::Temp qw/ tempfile tempdir /;
use Idval;
use Idval::Common;

our $audiodir = $main::topdir . '/data/audio';

my %startfiles = (
    'FLAC' => $audiodir . '/sbeep.flac',
    'MP3'  => $audiodir . '/sbeep.mp3',
    'OGG'  => $audiodir . '/sbeep.ogg',
    );

my @tempfiles = ();

END {
    my $options = Idval::Common::get_common_object('options');
    unlink @tempfiles unless $options->{'no-delete'};
}

sub get_audiodir
{
    my $rest = shift;

    return $main::topdir . '/data/audio' . $rest;
}

sub mktree
{
    my $datafile = shift;
    my $testpath = shift;
    my $idval = shift;

    my %info;
    my $dfh = IO::File->new($datafile, '<') || croak "Can't open input file \"$datafile\" for reading: $!\n";

    while (defined(my $line = <$dfh>))
    {
        $line =~ s/\#.*$//x;
        next if $line =~ m/^\s*$/;

        my ($fname, $type, $title, $artist, $album, $tracknum, $genre, $date) = split(/\s*\|\s*/, $line);
        #print join(",", ($fname, $type, $title, $artist, $album, $tracknum, $genre, $date)), "\n";
        chomp $date;

        my $path = File::Spec->catfile($testpath, "$fname." . lc($type));
        $info{$path}->{TYPE} = uc($type);
        $info{$path}->{TITLE} = $title;
        $info{$path}->{ARTIST} = $artist;
        $info{$path}->{ALBUM} = $album;
        $info{$path}->{TRACK} = $tracknum;
        $info{$path}->{GENRE} = $genre;
        $info{$path}->{YEAR} = $date;

        # If the generated file exists and it is newer than the datafile (from which it was made),
        # make a new one
        next if (-e $path) and (stat($path)->mtime > stat($datafile)->mtime);
        mkpath([dirname($path)]);
        copy($startfiles{$type}, $path) or croak("Copy of $startfiles{$type} to $path failed: $!\n");

        #Set up tags here
    }

    my $taglist = $idval->datastore();
    $taglist = Idval::Scripts::gettags($taglist, $idval->providers(), $testpath);
    my ($fh, $fname) = tempfile();
    push(@tempfiles, $fname);

    my $tag_record;
    my $type;
    my $prov;
    foreach my $key (sort keys %{$taglist->{RECORDS}})
    {
        $tag_record = $taglist->{RECORDS}->{$key};
    
        $tag_record->add_tag('TYPE', $info{$key}->{TYPE});
        $tag_record->add_tag('TITLE', $info{$key}->{TITLE});
        $tag_record->add_tag('ARTIST', $info{$key}->{ARTIST});
        $tag_record->add_tag('ALBUM', $info{$key}->{ALBUM});
        $tag_record->add_tag('TRACK', $info{$key}->{TRACK});
        $tag_record->add_tag('GENRE', $info{$key}->{GENRE});
        $tag_record->add_tag('YEAR', $info{$key}->{YEAR});
    }

    $taglist = Idval::Scripts::print($taglist, $idval->providers(), $fh);
    #print "Updating tags:\n";
    $taglist = Idval::Scripts::update($taglist, $idval->providers(), $fname);
    #$taglist = Idval::printlist($taglist, $idval->providers());

    return $taglist;
}



1;
