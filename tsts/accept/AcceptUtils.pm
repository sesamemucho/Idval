package AcceptUtils;
use Data::Dumper;
use Carp;
use IO::File;
use File::stat;
use File::Copy;
use File::Path;
use File::Basename;
use Idval;

our $audiodir = $main::topdir . '/data/audio';

our %startfiles = (
    'FLAC' => $audiodir . '/sbeep.flac',
    'MP3'  => $audiodir . '/sbeep.mp3',
    'OGG'  => $audiodir . '/sbeep.ogg',
    );

sub mktree
{
    my $datafile = shift;
    my $testpath = shift;
    my $idval = shift;

    my %info;
    my $dfh = IO::File->new($datafile, '<') || croak "Can't open input file \"$datafile\" for reading: $!\n";

    while (defined(my $line = <$dfh>))
    {
        $line =~ s/#.*$//;
        next if $line =~ m/^\s*$/;

        my ($fname, $type, $title, $artist, $album, $tracknum, $genre, $date) = split(/\s*\|\s*/, $line);
        #print join(",", ($fname, $type, $title, $artist, $album, $tracknum, $genre, $date)), "\n";
        chomp $date;

        my $path = File::Spec->catfile($testpath, "$fname." . lc($type));
        $info{$path}->{TYPE} = uc($type);
        $info{$path}->{TITLE} = $title;
        $info{$path}->{ARTIST} = $artist;
        $info{$path}->{ALBUM} = $album;
        $info{$path}->{TRACKNUMBER} = $tracknum;
        $info{$path}->{GENRE} = $genre;
        $info{$path}->{DATE} = $date;

        # If the generated file exists and it is newer than the datafile (from which it was made),
        # make a new one
        next if (-e $path) and (stat($path)->mtime > stat($datafile)->mtime);
        mkpath([dirname($path)]);
        copy($startfiles{$type}, $path) or croak("Copy of $startfiles{$type} to $path failed: $!\n");

        #Set up tags here
    }

    my $taglist = $idval->datastore();
    $taglist = Idval::Scripts::gettags($taglist, $idval->providers(), $testpath);
    #$taglist = Idval::Scripts::print($taglist, $idval->providers());

    my $record;
    my $type;
    my $prov;
    foreach my $key (sort keys %{$taglist->{RECORDS}})
    {
        $record = $taglist->{RECORDS}->{$key};
    
        $record->add_tag('TYPE', $info{$key}->{TYPE});
        $record->add_tag('TITLE', $info{$key}->{TITLE});
        $record->add_tag('ARTIST', $info{$key}->{ARTIST});
        $record->add_tag('ALBUM', $info{$key}->{ALBUM});
        $record->add_tag('TRACKNUMBER', $info{$key}->{TRACKNUMBER});
        $record->add_tag('GENRE', $info{$key}->{GENRE});
        $record->add_tag('DATE', $info{$key}->{DATE});
    }

    #print "Updating tags:\n";
    $taglist = Idval::Scripts::update($taglist, $idval->providers());
    #$taglist = Idval::printlist($taglist, $idval->providers());

    return $taglist;
}



1;
