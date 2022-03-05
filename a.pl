use Pod::Select;
use Pod::Text;

$input =<<EOF;
=head1 NAME

validate - Validates the tags in a local directory.

=head1 SYNOPSIS

validate validation-config-file

validation-config-file is a cascading configuration file that defines the allowable values for the tags.

=head1 OPTIONS
X<options>
This command has no options.

=head1 DESCRIPTION

X<desc>
B<This program> will read the given input file(s) and do something
useful with the contents thereof.

=cut

EOF
    my @sections = qw(NAME);

    my $temp_store = '';
my $usage = '';

    print "For $name (in", join(':', @sections), "), input is \"$input\"\n";
    open(my $INPUT, '<', \$input) || die "Can't open in-core filehandle for pod_input: $!\n";
open(my $TEMP, '>', \$temp_store) || die "Can't open in-core filehandle for temp_store: $!\n";
my $selector = new Pod::Select();
$selector->select(@sections);
$selector->parse_from_file($INPUT, $TEMP);

open($INPUT, '<', \$temp_store) || die "Can't open in-core filehandle for reading temp_store: $!\n";
open(my $FILE, '>', \$usage) || die "Can't open in-core filehandle: $!\n";
my $parser = new Pod::Text();
$parser->parse_from_filehandle($INPUT, $FILE);
close $FILE;
close $INPUT;

print "usage is: <$usage>\n";
