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
    my $mods;

    $mods = $logger->set_debugmask('Common,Provider,Logger');

    is_deeply([sort keys %{$mods}], [qw(Common::.*?::.*?::.*? Logger::.*?::.*?::.*? Provider::.*?::.*?::.*?)]);

    # Whitespace is OK too
    $mods = $logger->set_debugmask('Common Provider     Logger');

    is_deeply([sort keys %{$mods}], [qw(Common::.*?::.*?::.*? Logger::.*?::.*?::.*? Provider::.*?::.*?::.*?)]);
}

sub macros_expand_to_modules : Test(1)
{
    my $logger = Idval::Logger->new();
    my $mods;

    $mods = $logger->set_debugmask('Common Provider DBG_PROCESS Logger');

    is_deeply([sort keys %{$mods}],
              [qw(Common::.*?::.*?::.*? Converter::.*?::.*?::.*? DoDots::.*?::.*?::.*? Logger::.*?::.*?::.*? Provider::.*?::.*?::.*? ServiceLocator::.*?::.*?::.*?)]);
}


sub macros_expand_to_modules_recursively : Test(1)
{
    my $logger = Idval::Logger->new();
    my $mods;

    $Idval::Logger::DEBUG_MACROS{DBG_FOR_UNIT_TEST} = [qw(Common DBG_STARTUP DoDots)];
    $mods = $logger->set_debugmask('Common Provider DBG_FOR_UNIT_TEST Logger');

    is_deeply([sort keys %{$mods}],
              [qw(Common::.*?::.*?::.*? DoDots::.*?::.*?::.*? Logger::.*?::.*?::.*? Provider::.*?::.*?::.*? ProviderMgr::.*?::.*?::.*?)]);
}

sub macros_expand_to_modules_recursively_checked : Test(1)
{

    my $logger = Idval::Logger->new();
    my $mods;

    $Idval::Logger::DEBUG_MACROS{DBG_FOR_UNIT_TEST} = [qw(Common DBG_FOR_UNIT_TEST DoDots)];
    $mods = eval{$logger->set_debugmask('Common Provider DBG_FOR_UNIT_TEST Logger')};

    like($@, qr/mask spec contains a recursive macro/);
}

sub match_to_packages : Test(4)
{
    my $logger = Idval::Logger->new();
    my @pkgresult;
    my $q;
    my $l;

    $logger->set_debugmask('Common Provider Logger Commands::*');
    my $loglevel = $logger->accessor('LOGLEVEL');

    @pkgresult = $logger->_pkg_matches('Idval::Provider');
    is_deeply(\@pkgresult, [1, $loglevel]);

    @pkgresult = $logger->_pkg_matches('Idval::ProviderMgr');
    is_deeply(\@pkgresult, [0, -99]);

    @pkgresult = $logger->_pkg_matches('Idval::Commands::About');
    is_deeply(\@pkgresult, [1, $loglevel]);

    @pkgresult = $logger->_pkg_matches('Idval::Commands::Foo');
    is_deeply(\@pkgresult, [1, $loglevel]);
}

sub get_debugmask : Test(2)
{
    my $logger = Idval::Logger->new();
    my $mods;

    $mods = $logger->set_debugmask('Common Provider Logger Commands::*');
    is_deeply([sort keys %{$mods}], [qw(.*?::Commands::.*?::.*? Common::.*?::.*?::.*? Logger::.*?::.*?::.*? Provider::.*?::.*?::.*?)]);

    my $boo1 = $logger->get_debugmask();
    my $boo = [sort keys %{$boo1}];
    is_deeply($boo, [qw(.*?::Commands::.*?::.*? Common::.*?::.*?::.*? Logger::.*?::.*?::.*? Provider::.*?::.*?::.*?)]);

}

sub remove_from_debugmask : Test(1)
{
    my $logger = Idval::Logger->new();
    my $mods;

    $logger->set_debugmask('Common Provider Logger Commands::*');

    $logger->set_debugmask('-Commands::*');

    my $boo1 = $logger->get_debugmask();
    my $boo = [sort keys %{$boo1}];

    is_deeply($boo, [qw(Common::.*?::.*?::.*? Logger::.*?::.*?::.*? Provider::.*?::.*?::.*?)]);
}

sub add_to_debugmask : Test(1)
{
    my $logger = Idval::Logger->new();
    my $mods;

    $logger->set_debugmask('Common Provider Logger Commands::*');

    $logger->set_debugmask('+ProviderMgr');

    my $boo1 = $logger->get_debugmask();
    my $boo = [sort keys %{$boo1}];
    is_deeply($boo, [qw(.*?::Commands::.*?::.*? Common::.*?::.*?::.*? Logger::.*?::.*?::.*? Provider::.*?::.*?::.*? ProviderMgr::.*?::.*?::.*?)]);
}

sub reps_and_adds_and_removals_in_debugmask : Test(1)
{
    my $logger = Idval::Logger->new();
    my $mods;

    $logger->set_debugmask('Common +ProviderMgr Provider -Logger Logger Commands::*');

    my $boo1 = $logger->get_debugmask();
    my $boo = [sort keys %{$boo1}];
    is_deeply($boo, [qw(.*?::Commands::.*?::.*? Common::.*?::.*?::.*? Provider::.*?::.*?::.*? ProviderMgr::.*?::.*?::.*?)]);
}

sub multiple_removals_dont_fail : Test(1)
{
    my $logger = Idval::Logger->new();
    my $mods;

    $logger->set_debugmask('Common +ProviderMgr Provider -Logger Logger Commands::*');

    $logger->set_debugmask('-Commands::*');
    $logger->set_debugmask('-Commands::*');

    my $boo1 = $logger->get_debugmask();
    my $boo = [sort keys %{$boo1}];
    is_deeply($boo, [qw(Common::.*?::.*?::.*? Provider::.*?::.*?::.*? ProviderMgr::.*?::.*?::.*?)]);
}

sub multiple_additions_add_once : Test(1)
{
    my $logger = Idval::Logger->new();
    my $mods;

    $logger->set_debugmask('Common +ProviderMgr Provider -Logger Logger Commands::*');

    $logger->set_debugmask('+Commands::*');
    $logger->set_debugmask('+Commands::*');

    my $boo1 = $logger->get_debugmask();
    my $boo = [sort keys %{$boo1}];
    is_deeply($boo, [qw(.*?::Commands::.*?::.*? Common::.*?::.*?::.*? Provider::.*?::.*?::.*? ProviderMgr::.*?::.*?::.*?)]);
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

sub separate_levels_per_module : Test(5)
{
    my $logger = Idval::Logger->new();
    my $mods;
    my @pkgresult;

    $mods = $logger->set_debugmask('Common:2,Provider:4,Logger:0 Commands::*');

    #Doesn't affect the module list names
    is_deeply([sort keys %{$mods}], [qw(.*?::Commands::.*?::.*? Common::.*?::.*?::.*? Logger::.*?::.*?::.*? Provider::.*?::.*?::.*?)]);

    my $loglevel = $logger->accessor('LOGLEVEL');

    @pkgresult = $logger->_pkg_matches('Idval::Provider');
    is_deeply(\@pkgresult, [1, 4]);

    @pkgresult = $logger->_pkg_matches('Idval::ProviderMgr');
    is_deeply(\@pkgresult, [0, -99]);

    @pkgresult = $logger->_pkg_matches('Idval::Commands::About');
    is_deeply(\@pkgresult, [1, $loglevel]);

    @pkgresult = $logger->_pkg_matches('Idval::Logger');
    is_deeply(\@pkgresult, [1, 0]);
}

