

$foo = join(' ', @ARGV);

LOOP:
{
    print(to_pig($1)),            redo LOOP if $foo =~ m/\G(\w+)/gc;
    print("$1"),              redo LOOP if $foo =~ m/\G(\W+)/gc;
}

print "\n";

exit;

sub to_pig
{
    my $eng = shift;

    my $cap = ($eng =~ m/^[A-Z]/);
    $eng = lc $eng;

    if ($eng =~ m/^[aeiou]/i)
    {
        $eng = $eng . 'way';
    }
    else
    {
        $eng =~ s/^([^aeiou]+)(.\w*)(.*)/$2${1}ay$3/i;
    }

    $eng = ucfirst $eng if $cap;

    return $eng;
}
