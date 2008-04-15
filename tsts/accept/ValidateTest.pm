package ValidateTest;
use base qw(Test::Unit::TestCase);

use Benchmark qw(:all);
use Data::Dumper;
use FindBin;
use Memoize;
use Idval;
use Idval::Common;

use AcceptUtils;

our $data_dir = "tsts/accept_data/ValidateTest";

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

sub test_validation_with_one_error
{
    my $self = shift;
    my $expected_result =<<EOF;
STORED DATA CACHE:48: error: Wrong date!
EOF

    $taglist = AcceptUtils::mktree("$data_dir/val1.dat", "$data_dir/t/d1", $self->{IDVAL});

    my $io = IO::String->new();
    my $old_logfh = $self->{LOG}->accessor('LOG_OUT');
    $self->{LOG}->accessor('LOG_OUT', $io);
    $taglist = Idval::cmd_val($taglist, $self->{IDVAL}->providers(), "$data_dir/val1.cfg");
    $self->{LOG}->accessor('LOG_OUT', $old_logfh);

    $self->assert_equals($expected_result, ${$io->string_ref});
}


1;
