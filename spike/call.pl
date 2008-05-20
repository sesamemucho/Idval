
sub foofah
{
    my $a = shift;
    my $b = shift;

    print "Foofah has \"$a\" and \"$b\"\n";

    return 0;
}

sub goombah
{
    my $a = shift;
    my $b = shift;

    print "Goombah has \"$a\" and \"$b\"\n";

    return 1;
}

sub passes { my $func = $_[0]; return (eval {&$func(split(/,/, $_[1]))} != 0 ); }


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
}


