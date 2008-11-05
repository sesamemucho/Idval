package Idval::Logger::Test;
use strict;
use warnings;
use lib qw{t/lib};

use base qw(Test::Class);
use Test::More;

use Data::Dumper;
use Idval::Logger qw(:vars verbose chatty);

INIT { Test::Class->runtests } # here's the magic!

sub capture_logger
{
    my $log_rtn = shift;
    my $pkg = shift;
    my $level = shift;
    my $msg = shift;

    my $str_buf = 'nothing here';
    open my $oldout, ">&STDOUT"     or die "Can't dup STDOUT: $!";
    close STDOUT;
    open STDOUT, '>', \$str_buf or die "Can't redirect STDOUT: $!";
    select STDOUT; $| = 1;      # make unbuffered

    my $save_logger = Idval::Logger::get_logger();
    Idval::Logger::initialize_logger({log_out => 'STDOUT', debugmask=>$pkg, level=>$level});

    eval "$log_rtn(\$msg)";
    my $eval_status = $@ if $@;

    open STDOUT, ">&", $oldout or die "Can't dup \$oldout: $!";

    my $retval = $eval_status ? $eval_status : $str_buf;
    Idval::Logger::initialize_logger($save_logger);
    return $retval;
}

sub begin : Test(startup) {
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
    # Make sure DEBUG_MACROS is clean
    delete $Idval::Logger::DEBUG_MACROS{DBG_FOR_UNIT_TEST} if exists $Idval::Logger::DEBUG_MACROS{DBG_FOR_UNIT_TEST};
    return;
}

sub test_set_debugmask : Test(3)
{
    my $logger = Idval::Logger->new();
    my @foo;

    @foo = $logger->set_debugmask('Common,Provider,Logger');

    is_deeply(\@foo, [qw(Common::.*?::.*?::.*? Logger::.*?::.*?::.*? Provider::.*?::.*?::.*?)]); # Output is sorted

    # Whitespace is OK too
    @foo = $logger->set_debugmask('Common Provider     Logger');

    is_deeply(\@foo, [qw(Common::.*?::.*?::.*? Logger::.*?::.*?::.*? Provider::.*?::.*?::.*?)]); # Output is sorted
}

sub macros_expand_to_modules : Test(1)
{

    my $logger = Idval::Logger->new();
    my @foo;

    @foo = $logger->set_debugmask('Common Provider DBG_PROCESS Logger');

    is_deeply(\@foo, [qw(Common::.*?::.*?::.*? Converter::.*?::.*?::.*? DoDots::.*?::.*?::.*? Logger::.*?::.*?::.*? Provider::.*?::.*?::.*? ServiceLocator::.*?::.*?::.*?)]); # Output is sorted, and uniqued
}


sub macros_expand_to_modules_recursively : Test(1)
{

    my $logger = Idval::Logger->new();
    my @foo;

    $Idval::Logger::DEBUG_MACROS{DBG_FOR_UNIT_TEST} = [qw(Common DBG_STARTUP DoDots)];
    @foo = $logger->set_debugmask('Common Provider DBG_FOR_UNIT_TEST Logger');

    is_deeply(\@foo, [qw(Common::.*?::.*?::.*? DoDots::.*?::.*?::.*? Logger::.*?::.*?::.*? Provider::.*?::.*?::.*? ProviderMgr::.*?::.*?::.*?)]); # Output is sorted, and uniqued
}

sub macros_expand_to_modules_recursively_checked : Test(1)
{

    my $logger = Idval::Logger->new();
    my @foo;

    $Idval::Logger::DEBUG_MACROS{DBG_FOR_UNIT_TEST} = [qw(Common DBG_FOR_UNIT_TEST DoDots)];
    @foo = eval{$logger->set_debugmask('Common Provider DBG_FOR_UNIT_TEST Logger')};

    like($@, qr/mask spec contains a recursive macro/);
}

sub match_to_packages : Test(4)
{
    my $logger = Idval::Logger->new();
    my $q;

    $logger->set_debugmask('Common Provider Logger Commands::*');

    $q = $logger->_pkg_matches('Idval::Provider');
    ok($q);

    $q = $logger->_pkg_matches('Idval::ProviderMgr');
    ok(!$q);

    $q = $logger->_pkg_matches('Idval::Commands::About');
    ok($q);

    $q = $logger->_pkg_matches('Idval::Commands::Foo');
    ok($q);
}

sub get_debugmask : Test(2)
{
    my $logger = Idval::Logger->new();
    my @foo;

    @foo = $logger->set_debugmask('Common Provider Logger Commands::*');
    is_deeply(\@foo, [qw(.*?::Commands::.*?::.*? Common::.*?::.*?::.*? Logger::.*?::.*?::.*? Provider::.*?::.*?::.*?)]); # Output is sorted

    my $boo1 = $logger->get_debugmask();
    my $boo = [sort keys %{$boo1}];
    is_deeply($boo, [qw(.*?::Commands::.*?::.*? Common::.*?::.*?::.*? Logger::.*?::.*?::.*? Provider::.*?::.*?::.*?)]); # Output is sorted

}

sub remove_from_debugmask : Test(1)
{
    my $logger = Idval::Logger->new();
    my @foo;

    $logger->set_debugmask('Common Provider Logger Commands::*');

    $logger->set_debugmask('-Commands::*');

    my $boo1 = $logger->get_debugmask();
    my $boo = [sort keys %{$boo1}];

    is_deeply($boo, [qw(Common::.*?::.*?::.*? Logger::.*?::.*?::.*? Provider::.*?::.*?::.*?)]); # Output is sorted
}

sub add_to_debugmask : Test(1)
{
    my $logger = Idval::Logger->new();
    my @foo;

    $logger->set_debugmask('Common Provider Logger Commands::*');

    $logger->set_debugmask('+ProviderMgr');

    my $boo1 = $logger->get_debugmask();
    my $boo = [sort keys %{$boo1}];
    is_deeply($boo, [qw(.*?::Commands::.*?::.*? Common::.*?::.*?::.*? Logger::.*?::.*?::.*? Provider::.*?::.*?::.*? ProviderMgr::.*?::.*?::.*?)]); # Output is sorted
}

sub reps_and_adds_and_removals_in_debugmask : Test(1)
{
    my $logger = Idval::Logger->new();
    my @foo;

    $logger->set_debugmask('Common +ProviderMgr Provider -Logger Logger Commands::*');

    my $boo1 = $logger->get_debugmask();
    my $boo = [sort keys %{$boo1}];
    is_deeply($boo, [qw(.*?::Commands::.*?::.*? Common::.*?::.*?::.*? Provider::.*?::.*?::.*? ProviderMgr::.*?::.*?::.*?)]); # Output is sorted
}

sub multiple_removals_dont_fail : Test(1)
{
    my $logger = Idval::Logger->new();
    my @foo;

    $logger->set_debugmask('Common +ProviderMgr Provider -Logger Logger Commands::*');

    $logger->set_debugmask('-Commands::*');
    $logger->set_debugmask('-Commands::*');

    my $boo1 = $logger->get_debugmask();
    my $boo = [sort keys %{$boo1}];
    is_deeply($boo, [qw(Common::.*?::.*?::.*? Provider::.*?::.*?::.*? ProviderMgr::.*?::.*?::.*?)]); # Output is sorted
}

sub multiple_additions_add_once : Test(1)
{
    my $logger = Idval::Logger->new();
    my @foo;

    $logger->set_debugmask('Common +ProviderMgr Provider -Logger Logger Commands::*');

    $logger->set_debugmask('+Commands::*');
    $logger->set_debugmask('+Commands::*');

    my $boo1 = $logger->get_debugmask();
    my $boo = [sort keys %{$boo1}];
    is_deeply($boo, [qw(.*?::Commands::.*?::.*? Common::.*?::.*?::.*? Provider::.*?::.*?::.*? ProviderMgr::.*?::.*?::.*?)]); # Output is sorted
}

sub test_chatty : Test(2)
{
    my $msg = 'test_chatty test';

    my $result = capture_logger('chatty', 'Test', $L_SILENT, $msg);
    is($result, '');

    $result = capture_logger('chatty', 'Test', $L_CHATTY, $msg);
    is($result, "Idval::Logger::Test: $msg");
}

sub test_verbose : Test(3)
{
    my $msg = 'test_verbose test';

    my $result = capture_logger('verbose', 'Test', $L_SILENT, $msg);
    is($result, '');

    $result = capture_logger('verbose', 'Test', $L_VERBOSE, $msg);
    is($result, "Idval::Logger::Test: $msg");

    $result = capture_logger('verbose', 'Test', $L_CHATTY, $msg);
    is($result, "Idval::Logger::Test: $msg");
}

