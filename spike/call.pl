
%Idval::Validate::CheckFunctions = (foofah => 1,
                                    goombah => 1,
    );

my $perror;

sub Idval::Validate::foofah
{
    my $a = shift;
    my $b = shift;

    print "Foofah has \"$a\" and \"$b\"\n";

    return 0;
}

sub Idval::Validate::goombah
{
    my $a = shift;
    my $b = shift;

    print "Goombah has \"$a\" and \"$b\"\n";

    $perror = "Goo!";

    return 1;
}

sub perror
{
    my $retval = $perror;

    $perror = '';

    return $retval;
}

sub passes { my $funcname = $_[0];
             return undef unless exists($Idval::Validate::CheckFunctions{$funcname});
             my $func = "Idval::Validate::$funcname";
             return (&$func(split(/,/, $_[1])) != 0 ); }
#sub passes { my $func = 'Idval::Validate::' . $_[0]; return (&$func(split(/,/, $_[1])) != 0 ); }
#sub passes { my $func = $_[0]; return (eval {&$func(split(/,/, $_[1]))} != 0 ); }


while(1)
{
    print "well? ";
    my $line = <STDIN>;
    chomp $line;

    last if $line =~ m/quit/;

    my ($subr, $args) = ($line =~ /^\s*([\w:]+)\(([^()]*)\)/);

    print "subr: \"$subr\"\n";
    print "args: \"$args\"\n";

    print "\n";

    print "result: ", passes($subr, $args), "\n";

    print "perror: ", perror(), "\n";

}


