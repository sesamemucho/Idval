#!/usr/bin/perl -w

use strict;

use Test::Unit::Debug qw(debug_pkgs);
use Test::Unit::TestRunner;
use File::Glob ':glob';
use FindBin;
use Cwd;
#use lib ("$FindBin::Bin/../lib", "$FindBin::Bin/../tsts");
use lib (getcwd() . "/lib", getcwd() . "/tsts");
#use lib "$FindBin::Bin/../lib";
use TestUtils;

use Idval::Logger;

our @packages;

sub do_em
{
    Idval::Logger::_initialize_logger({level => 3});
    my $log = Idval::Logger::get_logger();
    print STDERR "Hello\n";
    print STDERR $log->str(), "\n";
    my @pkgs = ();
    #my @pkgs = bsd_glob("tsts/ConverterTest.pm");
    #my @pkgs = bsd_glob("tsts/ProviderTest.pm");
    ##my @pkgs = bsd_glob("tsts/ConfigTest.pm");
    #my @pkgs = bsd_glob("tsts/FileParseTest.pm");
    #my @pkgs = bsd_glob("tsts/RecordTest.pm");
    #my @pkgs = bsd_glob("tsts/TypeMapTest.pm");
    #my @pkgs = bsd_glob("tsts/FileStringTest.pm");
    #my @pkgs = bsd_glob("tsts/*Test.pm");

    # Re-create the test data, if needed
    #system("perl $FindBin::Bin/mktree.pl -q");

    # Uncomment and edit to debug individual packages.
    #debug_pkgs(qw/Test::Unit::TestCase/);

    foreach my $pkg (@pkgs)
    {
        my $testrunner = Test::Unit::TestRunner->new();
        $testrunner->start($pkg);
    }
}

# Recursively get package names
sub _get_pkgs
{
    no strict 'refs';
    my $pname = shift;
    my $p = \%{$pname};

    push(@packages, $pname);
    foreach my $pkg (grep(/\:\:$/, keys %$p))
    {
        next if $pkg =~ m/^[A-Z]+\:\:$/; # Don't mess with these?

        _get_pkgs($pname . $pkg);
    }
}

sub dt_pkgs
{
    my $pkg;
    local @packages;

    #TestUtils::_get_pkgs('Idval::');
    _get_pkgs('Idval::');

    print STDERR "packages are: ", join("\n", sort @packages), "\n";
    foreach my $name (@packages)
    {
        TestUtils::_unload_package($name);
        delete $INC{$name} if exists $INC{$name};
    }

    my @tst_pkgnames = grep(/^tsts.*\.pm$/, keys %INC);

    foreach my $name (@tst_pkgnames)
    {
        next if $name =~ m/TestUtils/;
        $pkg = $name;
        $pkg =~ s/\.pm//;
        $pkg =~ s{tsts/}{};

        printf STDERR "Unloading package \"$pkg\"\n";
        TestUtils::_unload_package($pkg);

        delete $INC{$name} if exists $INC{$name};
    }

    my $a = \%{main::};

    delete $a->{do_em};
    delete $a->{_get_pkgs};
    delete $a->{dt_pkgs};
}
sub pkgs
{
    my $pkg;
    local @packages;

    _get_pkgs('Idval::');

    #print STDERR "Got: ", join("\n", @packages), "\n";

    foreach my $name (@packages)
    {
        TestUtils::_unload_package($name);
        delete $INC{$name} if exists $INC{$name};
    }

    my @tst_pkgnames = grep(/^tsts.*Test\.pm$/, keys %INC);

    foreach my $name (@tst_pkgnames)
    {
        next if $name =~ m/TestUtils/;
        $pkg = $name;
        $pkg =~ s/\.pm//;
        $pkg =~ s{tsts/}{};

        TestUtils::_unload_package($pkg);

        delete $INC{$name} if exists $INC{$name};
    }

}

1;
