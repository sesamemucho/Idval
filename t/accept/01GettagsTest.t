package Idval::Gettags::Test::Acceptance;

use strict;
use warnings;
use lib qw{t/accept};

use base qw(Test::Class);
use Test::More;

use Data::Dumper;
use File::Basename;
use Idval;
use Idval::Common;

use AcceptUtils;

our $idval_obj;

INIT {
    Test::Class->runtests } # here's the magic!

sub begin : Test(startup) {
    # your state for fixture here
    $idval_obj = Idval->new({'verbose' => 0,
                             'quiet' => 0});
    #my ($prov_p, $reason) = AcceptUtils::are_providers_present();
    #Test::Class->SKIP_CLASS($reason) unless $prov_p;
    return;
}

sub end : Test(shutdown) {
    return;
}

sub before : Test(setup) {
    # provide fixture
    return;
}

sub after : Test(teardown) {
    # clean up after test
    return;
}

sub get_tags : Test(1)
{
    my $self = shift;
    my $idval = $idval_obj;
    my $errlist = '';

    my ($prov_p, $reason) = AcceptUtils::are_providers_present();

    return $reason unless $prov_p;

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
        elsif (!$taglist->get($file)->key_exists("TIT2"))
        {
            $errlist .= "no \"TIT2\" entry for $file.\n";
        }
        else
        {
            my $fname = lc(basename($file));
            #print STDERR "fname is \"$fname\", tag value is: \"" . $taglist->get($file)->get_value("TIT2") . "\"\n";
            if ($fname ne $taglist->get($file)->get_value("TIT2"))
            {
                $errlist .= "Bad TIT2 for \"$file\" (is \"" . $taglist->get($file)->get_value("TIT2") . "\")\n";
            }
        }
    }

    is($errlist, '');

    return;
}
