package Idval::UserPlugins::Up1;
use Idval::Setup;
use base qw(Idval::Plugin);

our $name = 'goober';

my $provs = Idval::Common::get_common_object('providers');
$provs->register_provider({provides=>'command', name=>$name});

sub new
{
    my $class = shift;
    #my $self = $class->SUPER::new(@_);
    my $self = {};
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

sub prolog
{
    return 0;
}

1;
