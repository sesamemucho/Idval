package Idval::Validate::Test::Acceptance;

use strict;
use warnings;
use lib qw{t/accept};

use base qw(Test::Class);
use Test::More;

use Data::Dumper;
use FindBin;
use File::Temp qw/ tempfile tempdir /;

our $tempfiles;
our $idval_obj;
my $data_dir;

INIT { Test::Class->runtests } # here's the magic!

sub begin : Test(startup) {
    # your state for fixture here
    $tempfiles = [];
    $idval_obj = Idval->new({'verbose' => 0,
                             'quiet' => 0});
    $data_dir = AcceptUtils::get_datadir("/ValidateTest");

    return;
}

sub end : Test(shutdown) {
    unlink @{$tempfiles} if defined($tempfiles);
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

sub run_validation_test
{
    my $cfg = shift;
    my $eval_status;

    my ($fh, $fname) = tempfile();
    print $fh $cfg;

    push(@{$tempfiles}, $fname);

    my $taglist = AcceptUtils::mktree("$data_dir/val1.dat", "$data_dir/t/d1", $idval_obj);

    #print "Validating:";
    #$taglist = Idval::Scripts::validate($taglist, $idval_obj->providers(), $fname);
    #print "Done\n";
    my $str_buf = 'nothing here';

    #my $oldout;
    open my $oldout, ">&STDOUT"     or die "Can't dup STDOUT: $!";
    close STDOUT;
    open STDOUT, '>', \$str_buf or die "Can't redirect STDOUT: $!";
    select STDOUT; $| = 1;      # make unbuffered

    eval {$taglist = Idval::Scripts::validate($taglist, $idval_obj->providers(), $fname);};
    $eval_status = $@ if $@;
    open STDOUT, ">&", $oldout or die "Can't dup \$oldout: $!";

    my $retval = $eval_status ? $eval_status : $str_buf;
    return $retval;
}

sub validation_with_one_error : Test(1)
{
    my $val_cfg =<<EOF;
{
        YEAR == 2007
        GRIPE = Date is wrong!
}
EOF
    my $expected_result = ".+?:\\d+: error: For YEAR, Date is wrong!\n";
    my $taglist = Idval::Scripts::about({}, $idval_obj->providers());
    my $test_result = run_validation_test($val_cfg);
    like($test_result, qr/$expected_result/);
    return;
}

sub test_validation_showing_that_two_selectors_AND_together
{
    my $self = shift;

    my $val_cfg =<<EOF;
{
        YEAR == 2006
        GENRE == Old-Time
        GRIPE = Too new for old-time
}
EOF
    my $expected_result = ".+?:\\d+: error: For GENRE, Too new for old-time\n" .
    ".+?:\\d+: error: For YEAR, Too new for old-time\n";
    my $test_result = $self->run_validation_test($val_cfg);
    $self->assert_matches(qr/$expected_result/, $test_result);
    return;
}

sub test_validation_showing_that_regexp_selectors_OR_together
{
    my $self = shift;

    my $val_cfg =<<EOF;
{
        .* has Flac
        GRIPE = Grumble Flac
}
EOF
    # We expect 9 errors: one for each tag of ARTIST, ALBUM, and TITLE
    # in each flac file, since these are the tags that contain "Flac"
    # (note that this is case-sensitive).

    my $expected_result =<<EOF;
.+?:\\d+: error: For ALBUM, Grumble Flac
.+?:\\d+: error: For ARTIST, Grumble Flac
.+?:\\d+: error: For TITLE, Grumble Flac
.+?:\\d+: error: For ALBUM, Grumble Flac
.+?:\\d+: error: For ARTIST, Grumble Flac
.+?:\\d+: error: For TITLE, Grumble Flac
.+?:\\d+: error: For ALBUM, Grumble Flac
.+?:\\d+: error: For ARTIST, Grumble Flac
.+?:\\d+: error: For TITLE, Grumble Flac
EOF

    my $test_result;
    $test_result = $self->run_validation_test($val_cfg);
    $self->assert_matches(qr/$expected_result/, $test_result);
    return;
}

sub test_validation_showing_that_regexp_selectors_OR_together_2
{
    my $self = shift;

    my $val_cfg =<<EOF;
{
        A.* has Flac
        GRIPE = Grumble Flac
}
EOF
    # We expect 6 errors this time, since we are only looking at tags
    # that start with A: one for each tag of ARTIST and ALBUM in each
    # flac file, since these are the tags that contain "Flac" (note
    # that this is case-sensitive).

    my $expected_result =<<EOF;
.+?:\\d+: error: For ALBUM, Grumble Flac
.+?:\\d+: error: For ARTIST, Grumble Flac
.+?:\\d+: error: For ALBUM, Grumble Flac
.+?:\\d+: error: For ARTIST, Grumble Flac
.+?:\\d+: error: For ALBUM, Grumble Flac
.+?:\\d+: error: For ARTIST, Grumble Flac
EOF

    my $test_result;
    $test_result = $self->run_validation_test($val_cfg);
    $self->assert_matches(qr/$expected_result/, $test_result);
    return;
}

sub test_validation_showing_that_ONLY_regexp_selectors_OR_together
{
    my $self = shift;

    my $val_cfg =<<EOF;
{
        A.* has Flac
        YEAR == 2005
        GRIPE = Grumble Flac
}
EOF
    # We expect 2 errors this time, since we are only looking at tags
    # that start with A that contain "Flac" AND for YEAR == 2005

    my $expected_result =<<EOF;
.+?:\\d+: error: For ARTIST, Grumble Flac
.+?:\\d+: error: For ALBUM, Grumble Flac
EOF

    my $test_result;
    $test_result = $self->run_validation_test($val_cfg);
    $self->assert_matches(qr/$expected_result/, $test_result);
    return;
}

sub test_validation_showing_nested_config_blocks
{
    my $self = shift;

    my $val_cfg =<<EOF;
{
    YEAR == 2005
    {
        A.* has Flac
        GRIPE = Grumble Flac
    }
}
EOF
    # We expect 2 errors this time, since we are only looking at tags
    # that start with A that contain "Flac" AND for YEAR == 2005

    my $expected_result =<<EOF;
.+?:\\d+: error: For ALBUM, Grumble Flac
.+?:\\d+: error: For ARTIST, Grumble Flac
EOF

    my $test_result;
    $test_result = $self->run_validation_test($val_cfg);
    $self->assert_matches(qr/$expected_result/, $test_result);
    return;
}

sub test_validation_with_bogus_pass_function
{
    my $self = shift;

    my $val_cfg =<<EOF;
{
    A.* passes NO_Function_Here
    GRIPE = Grumble Flac
}
EOF
    my $expected_result =<<EOF;
^Unknown function Idval::ValidateFuncs::NO_Function_Here.*
EOF

    my $test_result;
    $test_result = $self->run_validation_test($val_cfg);
    $self->assert_matches(qr/$expected_result/, $test_result);
    return;
}


1;
