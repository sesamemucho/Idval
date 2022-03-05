
package Idval::I18N::en_pgt;
use base qw(Idval::I18N::en);
use Data::Dumper;

sub init {
    my $lh = $_[0];  # a newborn handle
    $lh->SUPER::init();
    return;
}

%Lexicon = (
    '_AUTO' => 0,

    # set.pm
    "set_cmd=conf" => "set_cmd=onfcay",
    "set_cmd=debug" => "set_cmd=ebugday",

    'provmgr=set' => 'provmgr=etsay',

    'provmgr=MIDI' => 'provmgr=IDIM',
    'provmgr=OGG' => 'provmgr=OGGW',

    'sync_cmd=sync' => 'sync_cmd=yncsay',
    'sync_cmd=convert' => 'sync_cmd=onvertcay',
    'sync_cmd=filter' => 'sync_cmd=filter',
    'sync_cmd=remote_top' => 'sync_cmd=emoteray_optay',
    'sync_cmd=sync_dest' => 'sync_cmd=yncsay_estday',
    
    "set commands are: conf and debug\n" =>
    "etsay ommandscay areway: onfcay anday ebugday\n",

    "\nCurrent level is: [_1] ([_2])\n" =>
    "\nUrrentcay evelay isway: [_1] ([_2])\n",
);


1;

