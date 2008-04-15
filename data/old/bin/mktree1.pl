# Creates a small tree of small tagged (flac|mp3|ogg) files
#
use strict;
use warnings;
use open ':utf8';
use open ':std';

use Carp;
use IO::File;
use File::Path;
use File::Copy;
use File::Basename;
use File::Spec;
use File::Spec;
use Getopt::Long qw(:config pass_through);
use FindBin;
use Cwd qw(abs_path getcwd);

use lib (getcwd() . "/lib", getcwd() . "/tsts");

use Idval;

our (
    %startfile,
    $dfh,

    $testpath,
    $testbase,
    $testdir,
    $datafile,
    $clear,
    $quiet,

    %info,
    );

$| = 1;

%startfile = (
              'FLAC' => 'data/audio/sbeep.flac',
              'MP3'  => 'data/audio/sbeep.mp3',
              'OGG'  => 'data/audio/sbeep.ogg',
              );

$testbase = "$FindBin::Bin/..";
$testpath = '';
$datafile = '';
$clear = 0;
$quiet = 0;

my $result = GetOptions('clear' => \$clear,
                        'quiet' => \$quiet,
                        'file=s' => \$datafile,
                        'testpath=s' => \$testpath,
                       );

croak("Need a tree definition file and a directory") unless ($datafile and $testpath);

if ($clear and (-d $testpath))
{
    rmtree([$testpath], 0, 0);
}

print "Creating files in $testpath\n" unless $quiet;

$dfh = IO::File->new($datafile, '<') || die "Can't open input file \"$datafile\" for reading: $!\n";

while (defined(my $line = <$dfh>))
{
    $line =~ s/#.*$//;
    next if $line =~ m/^\s*$/;

    my ($fname, $type, $title, $artist, $album, $tracknum, $genre, $date) = split(/\s*\|\s*/, $line);
    #print join(",", ($fname, $type, $title, $artist, $album, $tracknum, $genre, $date)), "\n";
    chomp $date;

    my $path = File::Spec->catfile($testpath, "$fname." . lc($type));
    $info{$path}->{TYPE} = $type;
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
    copy($startfile{$type}, $path) or croak("Copy of $startfile{$type} to $path failed: $!\n");

    #Set up tags here
}

my $idval = Idval->new({'verbose' => 0,
                       'quiet' => 0});

my $taglist = $idval->datastore();
$taglist = Idval::gettags($taglist, $idval->providers(), $testpath);
#$taglist = Idval::printlist($taglist, $idval->providers());

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

print "Updating tags:\n" unless $quiet;
$taglist = Idval::update($taglist, $idval->providers());
#$taglist = Idval::printlist($taglist, $idval->providers());

exit;
