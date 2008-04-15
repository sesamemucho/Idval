package Idval::Ui;
use strict;
use warnings;

use Carp;
use Config;

use Idval::FileIO;

#
# Given a filename, see if it in the user's PATH
#
sub find_in_path
{
    my $exename = shift;
    my $exepath = '';
    my $testpath;

    # Clean
    $exename =~ s/\.[\.]*$//;
    $exename .= $Config{'_exe'};

    foreach my $path (File::Spec->path())
    {
        $testpath = File::catfile($path, $exename);
        if (Idval::FileIO::idv_test_exists($testpath))
        {
            $exepath = $testpath;
            break;
        }
    }

    return $exepath;
}
