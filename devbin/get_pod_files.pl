#
# Get a list of the pod documentation files in the system, given a language

use strict;
use warnings;
use File::Find;
use File::Temp;
use File::Basename;
use File::Path;
use FindBin;
use Cwd 'abs_path';

my $lang = shift @ARGV;

die "Need to specify a language (for instance, 'en_us')\n" unless $lang;

my $topdir = abs_path("$FindBin::Bin/../lib");

our @podlist = ();

if ($lang eq 'en_us')
{
    # Also get any .pm files that have pod content

    find(\&get_pm, $topdir);

}

find(\&get_pod, "$topdir/Idval/I18N/pods/$lang");

#print "Got: ", join("\n", @podlist), "\n";
#my @podlinks = map { $_ =~ s{$topdir/}{}; $_ } @podlist;

#print "Links: ", join("\n", @podlinks), "\n";

my $tempdir = File::Temp::tempdir();

print "#In: rm -rf $tempdir\n";
my $link;
my $dir;
my $status;
my @podlinks;

foreach my $pod (@podlist)
{
    ($link = $pod) =~ s{$topdir}{$tempdir};
    $dir = dirname $link;
    mkpath($dir);
    $status = symlink $pod, $link;
    push(@podlinks, $link);
}

print join("\n", @podlinks), "\n";

system("pod2latex", '-modify', '-full', "-out", "idv.tex", @podlinks);

exit 0;

sub get_pm
{
    return unless -f;
    my $fname = $_;
    return if $fname =~ m/~$/;
    return if $File::Find::dir =~ m{I18N/pods};
    #print "opening <$fname>\n";
    open(IN, '<', $fname) || die "Can't open $fname for reading: $!\n";
    my $str = do { local $/; <IN> };
    close IN;

    #print "Got one: ", abs_path($File::Find::name), "\n" if $str =~ m/=pod/s;
    push(@podlist, abs_path($File::Find::name)) if $str =~ m/=pod/s;
}

sub get_pod
{
    return unless -f;
    my $fname = $_;
    #print "Got one: ", abs_path($File::Find::name), "\n" if $fname =~ m/\.pod$/;
    push(@podlist, abs_path($File::Find::name)) if $fname =~ m/\.pod$/;
}

