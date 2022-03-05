package Idval::Provider::Test::Acceptance;

use strict;
use warnings;
use lib qw{t/accept};

use base qw(Test::Class);
use Test::More;

use Data::Dumper;
use FindBin;
use File::Temp qw/ tempfile tempdir /;
use File::Path;
use File::Find;

use Idval::Logger qw(:vars);

our $tempfiles;
our $remotedir;
our $idval_obj;
my $data_dir;
my $runtest_args;

INIT { Test::Class->runtests } # here's the magic!

sub begin : Test(startup) {
    # your state for fixture here
    $tempfiles = [];
    $idval_obj = Idval->new({'verbose' => 0,
                             'quiet' => 0});
    $data_dir = AcceptUtils::get_datadir("/ProviderTest");
    $remotedir = "$data_dir/t/rt";
    $runtest_args = {debugmask=>'+Sync:1', idval_obj=>$idval_obj,
                     cmd_sub=>\&Idval::Scripts::sync, tag_source=>\&do_mktree};
    return;
}

sub end : Test(shutdown) {
    #unlink @{$tempfiles} if defined($tempfiles);
    rmtree($remotedir, {keep_root => 1}) if defined($remotedir);
    return;
}


sub before : Test(setup) {
    # provide fixture
    return;
}

sub after : Test(teardown) {
    # clean up after test
    #unlink @{$tempfiles} if defined($tempfiles);
    rmtree($remotedir, {keep_root => 1}) if defined($remotedir);
    return;
}

use Idval;
use Idval::Common;

use AcceptUtils;

sub do_mktree
{
    return AcceptUtils::mktree("$data_dir/prov1.dat", "$data_dir/t/d1", $idval_obj);
}

sub sync_flac_to_flac : Test(4)
{
    my $sync_cfg =<<"EOF";
{
    convert = FLAC
    TYPE == FLAC
    remote_top = $remotedir
    sync_dest = flac1
    sync = 1
}
EOF
    $runtest_args->{cfg} = $sync_cfg;
    my $test_result = AcceptUtils::run_test_and_get_log($runtest_args);
    like($test_result, qr/3 records successfully processed/);

my $srcdir = "$data_dir/t/d1/flacs";
my $destdir = "$remotedir/flac1";

#print STDERR "$srcdir/fil01.flac: ", join(' ', stat("$srcdir/fil01.flac")), "\n";
#print STDERR "$destdir/fil01.flac: ", join(' ', stat("$destdir/fil01.flac")), "\n";
foreach my $file (qw(fil01 fil02 fil03))
{ 
    is((stat("$destdir/$file.flac"))[7], (stat("$srcdir/$file.flac"))[7], "filesize compare for $file.flac");
    #print STDERR "$file: sizes: ", (stat("$srcdir/$file.flac"))[7], ' ', (stat("$destdir/$file.flac"))[7], "\n";
}
#find({ wanted => sub {return unless -f; print STDERR "Looking at $File::Find::name, size is: ", (stat($_))[7], " bytes\n";}}, $remotedir);

}
