package Idval::UserPlugins::Up2;
use Idval::Setup;
use base qw(Idval::Plugin);

our $name = 'goober';

my $provs = Idval::Common::get_common_object('providers');
$provs->register_provider({provides=>'writes_tags', name=>$name, type=>'mp3'});

1;
