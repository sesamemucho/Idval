package Idval::UserPlugins::Simon;
use Idval::Setup;

use base qw(Idval::Converter);

our $name = 'whacker';

my $provs = Idval::Common::get_common_object('providers');
$provs->register_provider({provides=>'converts', name=>$name, from=>'FLAC', to=>'OGG'});

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
    my $src = shift;
    my $dest = shift;

    $self->set_param('name', $name);
}

1;
