package Idval::Validate::Test::Acceptance;

use strict;
use warnings;
use lib qw{t/accept};

use base qw(Test::Class);
use Test::More;

use Data::Dumper;
use FindBin;
use File::Temp qw/ tempfile tempdir /;

use Idval::Logger qw(:vars);

our $tempfiles;
our $idval_obj;
my $data_dir;
my $runtest_args;

INIT { Test::Class->runtests } # here's the magic!

sub begin : Test(startup) {
    # your state for fixture here
    $tempfiles = [];
    $idval_obj = Idval->new({'verbose' => 0,
                             'quiet' => 0});
    $data_dir = AcceptUtils::get_datadir("/ValidateTest");
    $runtest_args = {debugmask=>'+Validate:0', idval_obj=>$idval_obj,
                     cmd_sub=>\&Idval::Scripts::validate, tag_source=>\&do_mktree};
    return;
}

sub end : Test(shutdown) {
    #unlink @{$tempfiles} if defined($tempfiles);
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

use Idval;
use Idval::Common;

use AcceptUtils;

sub do_mktree
{
    return AcceptUtils::mktree("$data_dir/val1.dat", "$data_dir/t/d1", $idval_obj);
}

# sub run_validation_test
# {
#     my $cfg = shift;
#     my $do_logging = shift;
#     $do_logging = 1 unless defined($do_logging);
#     my $eval_status;

#     my ($fh, $fname) = tempfile();
#     print $fh $cfg;

#     push(@{$tempfiles}, $fname);

#     my $taglist = AcceptUtils::mktree("$data_dir/val1.dat", "$data_dir/t/d1", $idval_obj);

#     #print STDERR "Validating:";
#     #$taglist = Idval::Scripts::validate($taglist, $idval_obj->providers(), $fname);
#     my $str_buf = 'nothing here';

#     #my $oldout;
#     open my $oldout, ">&STDOUT"     or die "Can't dup STDOUT: $!";
#     close STDOUT;
#     open STDOUT, '>', \$str_buf or die "Can't redirect STDOUT: $!";
#     select STDOUT; $| = 1;      # make unbuffered

#     my $old_settings;
#     if ($do_logging)
#     {
#         $old_settings = Idval::Logger::get_settings();
#         Idval::Logger::re_init({log_out => 'STDOUT', debugmask=>'+Validate:0'});
#     }

#     eval {$taglist = Idval::Scripts::validate($taglist, $idval_obj->providers(), $fname);};
#     $eval_status = $@ if $@;

#     if ($do_logging)
#     {
#         Idval::Logger::re_init($old_settings);
#     }

#     open STDOUT, ">&", $oldout or die "Can't dup \$oldout: $!";

#     my $retval = $eval_status ? $eval_status : $str_buf;
#     return wantarray ? ($retval, $str_buf) : $retval;
# }

sub validation_with_one_error : Test(1)
{
    my $val_cfg =<<EOF;
{
        TYER == 2007
        GRIPE = Date is wrong!
}
EOF

    my ($prov_p, $reason) = AcceptUtils::are_providers_present();
    return $reason unless $prov_p;

    my $expected_result = ".+?:\\d+: error: For TYER: Date is wrong!\n";
    $runtest_args->{cfg} = $val_cfg;
    my $test_result = AcceptUtils::run_test_and_get_log($runtest_args);
    like($test_result, qr/$expected_result/);
    return;
}

sub test_validation_showing_that_two_selectors_AND_together : Test(1)
{
    my $val_cfg =<<EOF;
{
        TYER == 2006
        TCON == Old-Time
        GRIPE = Too new for old-time
}
EOF
    my ($prov_p, $reason) = AcceptUtils::are_providers_present();
    return $reason unless $prov_p;

    my $expected_result = ".+?:\\d+: error: For TCON: Too new for old-time\n" .
    ".+?:\\d+: error: For TYER: Too new for old-time\n";
    $runtest_args->{cfg} = $val_cfg;
    my $test_result = AcceptUtils::run_test_and_get_log($runtest_args);
    like($test_result, qr/$expected_result/);
    return;
}

sub test_validation_showing_that_regexp_selectors_OR_together : Test(1)
{
    my $val_cfg =<<EOF;
{
        .* has Flac
        GRIPE = Grumble Flac
}
EOF
    my ($prov_p, $reason) = AcceptUtils::are_providers_present();
    return $reason unless $prov_p;

    # We expect 9 errors: one for each tag of FILE, ARTIST (TPE1),
    # TALB, and TIT2 in each flac file, since these are the tags that
    # contain "Flac" (note that this is case-insensitive).

    my $expected_result =<<EOF;
.+?:\\d+: error: For FILE: Grumble Flac
.+?:\\d+: error: For TALB: Grumble Flac
.+?:\\d+: error: For TIT2: Grumble Flac
.+?:\\d+: error: For TPE1: Grumble Flac
.+?:\\d+: error: For FILE: Grumble Flac
.+?:\\d+: error: For TALB: Grumble Flac
.+?:\\d+: error: For TIT2: Grumble Flac
.+?:\\d+: error: For TPE1: Grumble Flac
.+?:\\d+: error: For FILE: Grumble Flac
.+?:\\d+: error: For TALB: Grumble Flac
.+?:\\d+: error: For TIT2: Grumble Flac
.+?:\\d+: error: For TPE1: Grumble Flac
EOF

    $runtest_args->{cfg} = $val_cfg;
    my $test_result = AcceptUtils::run_test_and_get_log($runtest_args);
    like($test_result, qr/$expected_result/);
    return;
}

sub test_validation_showing_that_regexp_selectors_OR_together_2 : Test(1)
{
    my $val_cfg =<<EOF;
{
        TALB|TPE1 has Flac
        GRIPE = Grumble Flac
}
EOF
    my ($prov_p, $reason) = AcceptUtils::are_providers_present();
    return $reason unless $prov_p;

    # We expect 6 errors this time, since we are only looking at tags
    # that start with A: one for each tag of TPE1 and TALB in each
    # flac file, since these are the tags that contain "Flac" (note
    # that this is case-sensitive).

    my $expected_result =<<EOF;
.+?:\\d+: error: For TALB: Grumble Flac
.+?:\\d+: error: For TPE1: Grumble Flac
.+?:\\d+: error: For TALB: Grumble Flac
.+?:\\d+: error: For TPE1: Grumble Flac
.+?:\\d+: error: For TALB: Grumble Flac
.+?:\\d+: error: For TPE1: Grumble Flac
EOF

    $runtest_args->{cfg} = $val_cfg;
    my $test_result = AcceptUtils::run_test_and_get_log($runtest_args);
    like($test_result, qr/$expected_result/);
    return;
}

sub test_validation_showing_that_ONLY_regexp_selectors_OR_together : Test(1)
{
    my $val_cfg =<<EOF;
{
        TALB|TPE1 has Flac
        TYER == 2005
        GRIPE = Grumble Flac
}
EOF
    my ($prov_p, $reason) = AcceptUtils::are_providers_present();
    return $reason unless $prov_p;

    # We expect 2 errors this time, since we are only looking at tags
    # that start with TA that contain "Flac" AND for TYER == 2005

    my $expected_result =<<EOF;
.+?:\\d+: error: For TALB: Grumble Flac
.+?:\\d+: error: For TPE1: Grumble Flac
.+?:\\d+: error: For TYER: Grumble Flac
EOF

    $runtest_args->{cfg} = $val_cfg;
    my $test_result = AcceptUtils::run_test_and_get_log($runtest_args);
    like($test_result, qr/^$expected_result$/);
    return;
}

sub test_validation_showing_nested_config_blocks : Test(1)
{
    my $val_cfg =<<EOF;
{
    TYER == 2005
    {
        TALB|TPE1 has Flac
        GRIPE = Grumble Flac
    }
}
EOF
    my ($prov_p, $reason) = AcceptUtils::are_providers_present();
    return $reason unless $prov_p;

    # We expect 2 errors this time, since we are only looking at tags
    # that start with A that contain "Flac" AND for TYER == 2005

    my $expected_result =<<EOF;
.+?:\\d+: error: For TALB: Grumble Flac
.+?:\\d+: error: For TPE1: Grumble Flac
EOF

    my $str;
    $runtest_args->{cfg} = $val_cfg;
    my $test_result = AcceptUtils::run_test_and_get_log($runtest_args);
    like($test_result, qr/$expected_result/);
    return;
}

sub test_validation_with_bogus_pass_function : Test(1)
{
    my $val_cfg =<<EOF;
{
    T.* passes NO_Function_Here
    GRIPE = Grumble Flac
}
EOF
    my $expected_result =<<EOF;
^Unknown function Idval::ValidateFuncs::NO_Function_Here.*
EOF

    my ($prov_p, $reason) = AcceptUtils::are_providers_present();
    return $reason unless $prov_p;

    $runtest_args->{cfg} = $val_cfg;
    my $test_result = AcceptUtils::run_test_and_get_log($runtest_args);
    like($test_result, qr/$expected_result/);
    return;
}
