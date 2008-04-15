package Idval::UserPlugins::Up1;
use Idval::Setup;
use base qw(Idval::Plugin);

our $name = 'goober';

my $provs = Idval::Common::get_common_object('providers');
$provs->register_provider({provides=>'writes_tags', name=>$name, type=>'mp3'});

sub new
{
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    bless($self, ref($class) || $class);
    $self->_init(@_);
    return $self;
}

sub _init
{
    my $self = shift;

    $self->set_param('name', $name);
}

1;


__END__
package Idval::UserPlugins::Up1;
use Idval::Setup;

my $provs = Idval::Common::get_common_object('providers');
$provs->register_provider({provides=>'reads_tags', name=>'goober', type=>'mp3'});

1;
