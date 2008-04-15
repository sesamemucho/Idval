package UiTest;
use base qw(Test::Unit::TestCase);

use Benchmark qw(:all);
use Data::Dumper;
use File::Glob ':glob';
use FindBin;

use TestUtils;
use Idval::Ui;
use Idval::FileIO;
use Idval::ServiceLocator;

our $testdir = "$FindBin::Bin/../tsts/unittest-data";
our $tree1 = {'testdir' => {
                            't' => {
                                    'd1' => {
                                             'flac' => {
                                                        'a0.flac' => "a0",
                                                        'a1.flac' => "a1",
                                                        'a2.flac' => "a2",
                                                        'a3.flac' => "a3",
                                                        'a4.flac' => "a4",
                                                        'a5.flac' => "a5",
                                                        },
                                             'mp3' => {
                                                        'a0.mp3' => "a0",
                                                        'a1.mp3' => "a1",
                                                        'a2.mp3' => "a2",
                                                        'a3.mp3' => "a3",
                                                        'a4.mp3' => "a4",
                                                        'a5.mp3' => "a5",
                                                        },
                                             'ogg' => {
                                                        'a0.ogg' => "a0",
                                                        'a1.ogg' => "a1",
                                                        'a2.ogg' => "a2",
                                                        'a3.ogg' => "a3",
                                                        'a4.ogg' => "a4",
                                                        'a5.ogg' => "a5",
                                                        },
                                             }
                                }
                            }
              };

sub new {
    my $self = shift()->SUPER::new(@_);
    # your state for fixture here
    $self->{NEWFILES} = [];
    # Tell the system to use the string-based filesystem services (i.e., the unit-testing version)
    Idval::ServiceLocator::provide('io_type', 'FileString');
    return $self;
}

sub set_up {
    # provide fixture
    Idval::FileString::idv_set_tree($tree1);
}

sub tear_down {
    my $self = shift;
    # clean up after test
    Idval::FileString::idv_clear_tree();
    unlink(@{$self->{NEWFILES}});
}

sub test_foo
{
    my $self = shift;

    $self->assert_equals(1, 1);
}
# sub test_prep_one_requested_item
# {
#     my $self = shift;

#     my $fc = FakeConfig->new("foo");
#     my $ret = Idval::Ui::prep_args($fc, $fc, 'gubber', ['a'], 'a', 'b', 'c');

#     $self->assert_deep_equals({'ITEM' => [
#                                           'a',
#                                          ]}, $ret);
# }

# sub test_prep_all_requested_items
# {
#     my $self = shift;
#     my $ret;

#     my $fc = FakeConfig->new("foo");
#     eval {$ret = Idval::Ui::prep_args($fc, $fc, 'gubber', ['a+'], 'a', 'b', 'c')};
#     my $str = $@;
#     $self->assert_not_null($ret);
#     $self->assert_deep_equals({'ITEM' => [
#                                           'a',
#                                           'b',
#                                           'c'
#                                          ]}, $ret);
# }

# sub test_prep_two_requested_items
# {
#     my $self = shift;

#     my $fc = FakeConfig->new("foo");
#     my $ret = Idval::Ui::prep_args($fc, $fc, 'gubber', ['a', 'a'], 'a', 'b');

#     $self->assert_deep_equals({'ITEM' => [
#                                           'a',
#                                           'b',
#                                          ]}, $ret);
# }

# sub test_prep_insufficient_requested_items
# {
#     my $self = shift;

#     my $fc = FakeConfig->new();
#     my $ret;

#     eval {$ret = Idval::Ui::prep_args($fc, $fc, 'gubber', ['a', 'a'], 'a')};
#     my $str = $@;
#     $self->assert_null($ret);
#     $self->assert_matches(qr/^Not enough parameters for command/, $str);
# }

# sub test_prep_two_input_files
# {
#     my $self = shift;
#     my $file;
#     my $fc = FakeConfig->new();
#     system("echo foo > $testdir/tstprep1.txt");
#     system("echo boo > $testdir/tstprep2.txt");
#     push(@{$self->{NEWFILES}}, "$testdir/tstprep1.txt",  "$testdir/tstprep2.txt");

#     my $ret = Idval::Ui::prep_args($fc, $fc, 'gubber', ['i', 'i'], "$testdir/tstprep1.txt",  "$testdir/tstprep2.txt");

#     $file = shift(@{$ret->{INFILE}});
#     $self->assert_equals($file->get_filename(), "$testdir/tstprep1.txt");
#     $file->close();

#     $file = shift(@{$ret->{INFILE}});
#     $self->assert_equals($file->get_filename(), "$testdir/tstprep2.txt");
#     $file->close();
# }

# sub test_prep_two_input_files_from_command_file
# {
#     my $self = shift;
#     my $file;
#     my $fc = FakeConfig->new("$testdir/tstprep1c.txt",  "$testdir/tstprep2c.txt");
#     system("echo foo > $testdir/tstprep1c.txt");
#     system("echo boo > $testdir/tstprep2c.txt");
#     push(@{$self->{NEWFILES}}, "$testdir/tstprep1c.txt",  "$testdir/tstprep2c.txt");

#     my $ret;
#     eval {$ret = Idval::Ui::prep_args($fc, $fc, 'gubber', ['i', 'i'])};
#     my $str = $@;

#     $self->assert_not_null($ret);
#     $file = shift(@{$ret->{INFILE}});
#     $self->assert_equals($file->get_filename(), "$testdir/tstprep1c.txt");
#     $file->close();

#     $file = shift(@{$ret->{INFILE}});
#     $self->assert_equals($file->get_filename(), "$testdir/tstprep2c.txt");
#     $file->close();
# }

sub test_get_source_from_dirs_1
{
    my $self = shift;
    my $fc = TestUtils::FakeConfig->new();
    my $fp = TestUtils::FakeProvider->new(sub{
        my $record = shift;
        my $filename = shift;
        print STDERR "Reading from $filename\n";
                                           });

    my $coll = Idval::Ui::get_source_from_dirs($fp, $fc, "testdir/t/d1");

    $self->assert_equals(18, scalar(keys(%{$coll->{RECORDS}})));

    #print STDERR Dumper($coll->{RECORDS});
    my @gubb = values %{$coll->{RECORDS}};
    my ($rec1) = grep($_->{FILE} =~ /a4\.flac/, @gubb);
    $self->assert_equals($rec1->{CLASS}, 'MUSIC');

    ($rec1) = grep($_->{FILE} =~ /a3\.mp3/, @gubb);
    $self->assert_equals($rec1->{TYPE}, 'MP3');

    ($rec1) = grep($_->{FILE} =~ /a2\.ogg/, @gubb);
    $self->assert_equals($rec1->{TYPE}, 'OGG');
}

package FakeProvider1;

sub new
{
    my $class = shift;
    my $self = {};
    bless($self, ref($class) || $class);
    $self->_init(@_);
    return $self;
}

sub _init
{
    my $self = shift;
    my $reader = shift;

    $self->{READER} = $reader;
    $self->{PROVS} = [
                      TestUtils::FakeConverter->new({'MP3' => [qw{ mp3 }]}, {'MUSIC' => [qw( MP3 )]}),
                      TestUtils::FakeConverter->new({'MP3' => [qw{ mp3 }]}, {'MUSIC' => [qw( MP3 )]}),
                      TestUtils::FakeConverter->new({'OGG' => [qw{ ogg }]}, {'MUSIC' => [qw( OGG )]}),
                      TestUtils::FakeConverter->new({'FLAC' => [qw{ FLAC FLAC16 }]}, {'MUSIC' => [qw( FLAC )]}),
                      ];
}

sub get_provider
{
    my $self = shift;
    my $provider = shift;
    my $src = shift;
    my $dest = shift || 'DONE';

    return $self->{READER};
}

sub get_all_active_providers
{
    my $self = shift;
    my @types = @_;

    return @{$self->{PROVS}};
}
1;
