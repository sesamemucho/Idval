# Creates a small tree of small tagged (flac|mp3|ogg) files
#
use warnings;
use open ':utf8';
use open ':std';

use Carp;
use IO::File;
use File::Path;
use File::Copy;
use File::Basename;
use File::Spec;
use Getopt::Long;
use FindBin;
use Cwd 'abs_path';

%startfile = (
              'FLAC' => 'data/audio/sbeep.flac',
              'MP3'  => 'data/audio/sbeep.mp3',
              'OGG'  => 'data/audio/sbeep.ogg',
              );

$testbase = "$FindBin::Bin/..";
$testdir = '';
$datafile = '';
$metaflac_exe = 'metaflac';
$Tag_exe = 'Tag.exe';
$vorbiscomment_exe = 'vorbiscomment';
$clear = 0;
$quiet = 0;

my $result = GetOptions('clear' => \$clear,
                        'quiet' => \$quiet,
                        'file=s' => \$datafile,
                        'testdir=s' => \$testdir,
                       );

if (not $testdir)
{
    $testpath = File::Spec->catdir($testbase, 'tsts/accept_data/t/d1');
}
elsif ($testdir =~ m|^/|)
{
    $testpath = $testdir;
}
else
{
    $testpath = File::Spec->catdir($testbase, $testdir);
}

if ($clear and (-d $testpath))
{
    rmtree([$testpath], 0, 0);
}

print "Creating files in $testpath\n" unless $quiet;

if ($datafile)
{
    $dfh = IO::File->new($datafile, '<') || die "Can't open input file \"$datafile\" for reading: $!\n";
}
else
{
    $dfh = main::DATA;
}

while (defined($line = <$dfh>))
{
    $line =~ s/#.*$//;
    next if $line =~ m/^\s*$/;

    my ($fname, $type, $title, $artist, $album, $tracknum, $genre, $date) = split(/\s*\|\s*/, $line);
    #print join(",", ($fname, $type, $title, $artist, $album, $tracknum, $genre, $date)), "\n";
    chomp $date;

    my $path = File::Spec->catfile($testpath, "$fname." . lc($type));

    next if -e $path;
    mkpath([dirname($path)]);
    copy($startfile{$type}, $path) or croak("Copy of $startfile{$type} to $path failed: $!\n");
    if ($type eq 'FLAC')
    {
        system("$metaflac_exe " .
               "--set-tag=TITLE=\"$title\" " .
               "--set-tag=ARTIST=\"$artist\" " .
               "--set-tag=ALBUM=\"$album\" " .
               "--set-tag=TRACKNUMBER=\"" . sprintf("%02d", $tracknum) . "\" " .
               "--set-tag=GENRE=\"$genre\" " .
               "--set-tag=DATE=\"$date\" " .
               $path
               );
    }

    if ($type eq 'MP3')
    {
        $path = abs_path($path);
        $path =~ s{/cygdrive/(.)/}{${1}:/};

        my $cmd = "$Tag_exe " .
            "--title \"$title\" " .
            "--artist \"$artist\" " .
            "--album \"$album\" ".
            "--track \"" . sprintf("%02d", $tracknum) . "\" ".
            "--genre \"$genre\" " .
            "--year \"$date\" $path 2>&1";

        my $retval = qx "$cmd";
        print "\nFor file $path:\n$retval\n" if $retval =~ m/error/i;
    }

    if ($type eq 'OGG')
    {
        system("$vorbiscomment_exe " .
               "-t TITLE=\"$title\" " .
               "-t ARTIST=\"$artist\" " .
               "-t ALBUM=\"$album\" " .
               "-t TRACKNUMBER=\"" . sprintf("%02d", $tracknum) . "\" " .
               "-t GENRE=\"$genre\" " .
               "-t DATE=\"$date\" " .
               $path
               );
    }
}

exit;

sub do_makefile
{
    my $id = shift;

    my $filename = File::Spec->catfile($testpath, "a${id}.flac");

    copy($startfile, $filename) or croak("Copy to $filename failed: $!\n");

    system("$metaflac_exe " .
           "--set-tag=TITLE=\"Title number $id\" " .
           "--set-tag=ARTIST=\"Test Artist\" " .
           "--set-tag=ALBUM=\"Test Album\" " .
           "--set-tag=TRACKNUMBER=\"" . sprintf("%02d", $id) . "\" " .
           "--set-tag=GENRE=\"Folk\" " .
           "--set-tag=DATE=\"2006\" " .
           $filename
           );
}

__DATA__

flac/a0         |FLAC  |Roll Em On The Ground         |Fate Norris Playboys           |CoOTM V1       |1 |Folk | 2006
flac/a1         |FLAC  |Charming Betsy                |Georgia Organ Grinders         |CoOTM V1       |2 |Folk | 2006
flac/a2         |FLAC  |Old Flannagan                 |Blueridge Mountineers          |CoOTM V1       |3 |Folk | 2006
flac/a3         |FLAC  |The Fiddlin Bootleggers       |Boys From Wildcat Hollow       |CoOTM V1       |4 |Folk | 2006
flac/a4         |FLAC  |Fresno Blues                  |Johnny And Albert Crockett     |CoOTM V1       |5 |Folk | 2006
flac/a5         |FLAC  |Pikes' Peak                   |Ted Sharp Hinman And Sharp     |CoOTM V1       |6 |Folk | 2006

mp3/a0          |MP3   |Roll Em On The Ground         |Fate Norris Playboys           |CoOTM V1       |1 |Folk | 2006
mp3/a1          |MP3   |Charming Betsy                |Georgia Organ Grinders         |CoOTM V1       |2 |Folk | 2006
mp3/a2          |MP3   |Old Flannagan                 |Blueridge Mountineers          |CoOTM V1       |3 |Folk | 2006
mp3/a3          |MP3   |The Fiddlin Bootleggers       |Boys From Wildcat Hollow       |CoOTM V1       |4 |Folk | 2006
mp3/a4          |MP3   |Fresno Blues                  |Johnny And Albert Crockett     |CoOTM V1       |5 |Folk | 2006
mp3/a5          |MP3   |Pikes' Peak                   |Ted Sharp Hinman And Sharp     |CoOTM V1       |6 |Folk | 2006

ogg/a0          |OGG   |Roll Em On The Ground         |Fate Norris Playboys           |CoOTM V1       |1 |Folk | 2006
ogg/a1          |OGG   |Charming Betsy                |Georgia Organ Grinders         |CoOTM V1       |2 |Folk | 2006
ogg/a2          |OGG   |Old Flannagan                 |Blueridge Mountineers          |CoOTM V1       |3 |Folk | 2006
ogg/a3          |OGG   |The Fiddlin Bootleggers       |Boys From Wildcat Hollow       |CoOTM V1       |4 |Folk | 2006
ogg/a4          |OGG   |Fresno Blues                  |Johnny And Albert Crockett     |CoOTM V1       |5 |Folk | 2006
ogg/a5          |OGG   |Pikes' Peak                   |Ted Sharp Hinman And Sharp     |CoOTM V1       |6 |Folk | 2006

