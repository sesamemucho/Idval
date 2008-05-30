package GettagsTest;

use strict;
use warnings;

use base qw(Test::Unit::TestCase);

use Benchmark qw(:all);
use Data::Dumper;
use File::Basename;
use Idval;
use Idval::Common;

use AcceptUtils;

#our $data_dir = $main::topdir . '/' . "tsts/accept_data/ValidateTest";

sub new {
    my $self = shift()->SUPER::new(@_);
    # your state for fixture here
    $self->{IDVAL} = Idval->new({'verbose' => 0,
                                 'quiet' => 0});
    $self->{LOG} = Idval::Common::get_logger();
    return $self;
}

sub set_up {
    # provide fixture
}
sub tear_down {
    # clean up after test
}

sub test_gettags
{
    my $self = shift;
    my $idval = $self->{IDVAL};
    my $errlist = '';

    my @files = map{ AcceptUtils::get_audiodir("/sbeep$_") } qw(.flac .ogg .mp3);
    my $taglist = $idval->datastore();
    $taglist = Idval::Scripts::gettags($taglist, $idval->providers(), $AcceptUtils::audiodir);
    #$taglist = Idval::Scripts::print($taglist, $idval->providers());

    #print STDERR "Checking: ", @files, "\n";
    foreach my $file (@files)
    {
        if (!$taglist->key_exists($file))
        {
            $errlist .= "No tag entries for \"$file\". Tag reader not present?\n";
        }
        elsif (!$taglist->get($file)->key_exists("TITLE"))
        {
            $errlist .= "no \"TITLE\" entry for $file.\n";
        }
        else
        {
            my $fname = lc(basename($file));
            #print STDERR "fname is \"$fname\", tag value is: \"" . $taglist->get($file)->get_value("TITLE") . "\"\n";
            if ($fname ne $taglist->get($file)->get_value("TITLE"))
            {
                $errlist .= "Bad TITLE for \"$file\" (is \"" . $taglist->get($file)->get_value("TITLE") . "\")\n";
            }
        }
    }

    $self->assert(0, $errlist) if $errlist;

    return;
}

1;
