# Creates a small tree of small tagged (flac|mp3|ogg) files
#
use strict;
use warnings;
use open ':utf8';
use open ':std';

use Carp;
use Cwd qw(abs_path getcwd);
use File::Basename;
use File::Path;
use File::Spec;
use Getopt::Long;
use IO::File;

use lib (getcwd() . "/lib", getcwd() . "/tsts");

use Idval;

our (
    %startfile,
    $dfh,

    $datapath,
    $clear,
    $quiet,
    $valfile,

    %info,
    );

$| = 1;
$valfile = '';
$datapath = '';

$clear = 0;
$quiet = 0;

my $result = GetOptions('clear' => \$clear,
                        'quiet' => \$quiet,
                        'valfile=s' => \$valfile,
                        'datapath=s' => \$datapath,
                       );

my $taglist_file = shift @ARGV || '';

croak("Need a validation cfg file and a data tree") unless ($valfile and $datapath);

my $idval = Idval->new({'verbose' => 0,
                       'quiet' => 0});


my $taglist = $idval->datastore();
$taglist = $taglist_file ? 
    Idval::read_data($taglist, $idval->providers(), $taglist_file) :
    Idval::gettags($taglist, $idval->providers(), $datapath);

#$taglist = Idval::printlist($taglist, $idval->providers());
$taglist = Idval::validate($taglist, $idval->providers(), $valfile);

exit;

sub make_cfg
{
    my $cfg =<<'EOF';
{
        TAGNAME = DATE
        TAGVALUE = 2006
        GRIPE = Wrong date!
}
EOF

    my $ofh = IO::File->new($val_cfg_file, ">");
croak "Can't open \"$val_cfg_file\" for writing: $!\n" unless $ofh;
$ofh->print($cfg);
$ofh->close();
}
