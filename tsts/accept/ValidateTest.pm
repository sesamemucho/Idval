package ValidateTest;
use base qw(Test::Unit::TestCase);

use strict;
use warnings;

use Benchmark qw(:all);
use Data::Dumper;
use FindBin;
use Memoize;
use File::Temp qw/ tempfile tempdir /;

my @tempfiles = ();

END {
    my $options = Idval::Common::get_common_object('options');
    unlink @tempfiles unless $options->{'no-delete'};
}


use Idval;
use Idval::Common;

use AcceptUtils;

my $data_dir = $main::topdir . '/' . "tsts/accept_data/ValidateTest";

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

# sub test_get
# {
#     my $self = shift;
#     Idval::FileString::idv_add_file('/testdir/gt1.txt', "\ngubber = 3\nhubber=4\n\n");
#     my $obj = Idval::Config->new('/testdir/gt1.txt');
#     $self->assert_equals(3, $obj->get_single_value('gubber'));
#     $self->assert_equals(4, $obj->get_single_value('hubber'));
# }

sub run_validation_test
{
    my $self = shift;
    my $cfg = shift;
    my $eval_status;

    my ($fh, $fname) = tempfile();
    print $fh $cfg;

    push(@tempfiles, $fname);

    my $taglist = AcceptUtils::mktree("$data_dir/val1.dat", "$data_dir/t/d1", $self->{IDVAL});

    #print "Validating:";
    #$taglist = Idval::Scripts::validate($taglist, $self->{IDVAL}->providers(), $fname);
    #print "Done\n";
    my $str_buf = 'nothing here';

    #my $oldout;
    open my $oldout, ">&STDOUT"     or die "Can't dup STDOUT: $!";
    close STDOUT;
    open STDOUT, '>', \$str_buf or die "Can't redirect STDOUT: $!";
    select STDOUT; $| = 1;      # make unbuffered

    eval {$taglist = Idval::Scripts::validate($taglist, $self->{IDVAL}->providers(), $fname);};
    $eval_status = $@ if $@;
    open STDOUT, ">&", $oldout or die "Can't dup \$oldout: $!";

    my $retval = $eval_status ? $eval_status : $str_buf;
    return $retval;
}

sub test_validation_with_one_error
{
    my $self = shift;

    my $val_cfg =<<EOF;
{
        YEAR == 2007
        GRIPE = Date is wrong!
}
EOF
    my $expected_result = ".+?:\\d+: error: For YEAR, Date is wrong!\n";
    my $test_result = $self->run_validation_test($val_cfg);
    $self->assert_matches(qr/$expected_result/, $test_result);
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
