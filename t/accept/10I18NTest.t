# This test requires 'LC_ALL' to be set to 'en_pig', and assumes that
# the localizations that this test requires be present in the
# Idval/I18n/en_pig.pm file. If en_pig is active, then this should be
# the only test run, as the others will almost surely fail.

package Idval::I18N::Test::Acceptance;


# In particular, before Idval::Logger gets loaded.
use Idval::I18N;
use Idval::I18N::en_pgt;
sub setup_pgt_lexicon
{
    # If we need to change the Lexicon on the fly...
#     %Idval::I18N::en_pgt::Lexicon = (
#     '_AUTO' => 0,

#     # set.pm
#     "set_cmd=conf" => "set_cmd=onfcay",
#     "set_cmd=debug" => "set_cmd=ebugday",
#     "set_cmd=level" => "set_cmd=evelay",

#     'prov_name=set' => 'prov_name=etsay',

#     "set commands are: conf, debug, level\n" =>
#     "etsay ommandscay areway: onfcay, ebugday, evelay\n",

#     "\nCurrent level is: [_1] ([_2])\n" =>
#     "\nUrrentcay evelay isway: [_1] ([_2])\n",
# );
    return;
}

BEGIN { if (defined($ENV{"IDV_RUN_LANG_TESTS"})) {Idval::I18N::idv_set_language('en_PGT.UTF-8'); setup_pgt_lexicon();}}

use strict;
use warnings;
use lib qw{t/accept};

use base qw(Test::Class);
use Test::More;

use Data::Dumper;
use FindBin;
use File::Temp qw/ tempfile tempdir /;
use File::Remove qw(remove);
use File::Spec;
use IO::File;
use Carp;

use Idval::Logger qw(:vars);

our @tempfiles;

our $idval_obj;
my $data_dir;

# To set up the language test environment, make sure the system knows
# about the locale 'en_PGT.UTF-8' and the environmental
# IDV_RUN_LANG_TESTS is set (to anything).

INIT { if (!defined($ENV{"IDV_RUN_LANG_TESTS"})) {Test::Class->SKIP_ALL('Language test environment not set up');}
       Test::Class->runtests } # here's the magic!

sub begin : Test(startup) {
    # your state for fixture here
    @tempfiles = ();
Idval::Logger::re_init({log_out => 'STDERR'});
    $idval_obj = Idval->new({'verbose' => 0,
                             'quiet' => 0});
    $data_dir = AcceptUtils::get_datadir("/I18NTest");

    return;
}

sub end : Test(shutdown) {
    Idval::I18N::idv_set_language('');
    #remove(\1, @tempfiles) if @tempfiles;
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

# sub i18n_with_translated_command_name_and_logger_string : Test(1)
# {
#     my $runtest_args = {debugmask=>'+Validate:0', idval_obj=>$idval_obj,
#                         cmd_sub=>\&Idval::Scripts::etsay, tag_source=>{}};

#     my $test_result = AcceptUtils::run_test_and_get_log($runtest_args);
#     is($test_result, "etsay ommandscay areway: onfcay, ebugday, evelay\n");
#     return;
# }

sub i18n_sync1 : Test(1)
{
    my $remotedir = File::Spec->catdir($data_dir, 'rem');
    mkdir($remotedir);
    push(@tempfiles, $remotedir);
    my $syncdat = File::Spec->catfile($data_dir, 'sync.dat');
    push(@tempfiles, $syncdat);

    my $sync_dat =<<EOF;
onvertcay = OGGW
emoteray_optay = $remotedir
yncsay_estday = foo

{
    TIT2 == sbeep.flac
    yncsay = 1
}
EOF

    my $sfh = IO::File->new($syncdat, '>') || croak "Can't open output file \"$syncdat\" for writing: $!\n";
$sfh->print($sync_dat);
$sfh->close();

    my $taglist = $idval_obj->datastore();
    $taglist = Idval::Scripts::gettags($taglist, $idval_obj->providers(), "$data_dir/../../samples");
print STDERR "After gettags, tag list is: ", Dumper($taglist);
Idval::Logger::re_init({log_out => 'STDERR'});
    $taglist = Idval::Scripts::sync($taglist, $idval_obj->providers(), $syncdat);
print STDERR "After sync, tag list is: ", Dumper($taglist);
Idval::Logger::re_init({log_out => 'STDOUT'});

is(1,1);
}
