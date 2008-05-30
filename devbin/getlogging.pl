#
# Find out where logger calls are used in idval modules
#
# Usage:
#
#   perl getlogging.pl modname-1 [modname-2 [...]]
#

use warnings;

my $get_debugmask = 0;

my %logfuncs;

OUTER: while(<>)
{
    #print "Checking <$_>\n";
    $get_debugmask and m/debugmask\s*\=\>\s+(\$\w+),/ and do {
        $logfuncs{$get_debugmask}->{DEBUGMASK} = $1;
        $get_debugmask = 0;
        next;
    };

    m/\*(\w+)\s*=\s*Idval::Common::make_custom_logger\(\{level \=\>\s+(\$\w+),/ and do {
        #print "1 is <$1> and 2 is <$2>\n";
        $logfuncs{$1}->{LEVEL} = $2;
        $get_debugmask = $1;
        next;
    };

    m/\$self->\{LOG\}-\>(\w+)\s*\((\$\w+)\s*,\s*(.*)$/ and do {
        my $type = '$' . uc($1);
        # D for 'direct'
        print "D $ARGV: $type ($2): $3\n";
        next;
    };

    foreach my $item (keys %logfuncs)
    {
        m/$item\((.*)$/ and do {
            # F for 'function'
            print "F $ARGV: ", $logfuncs{$item}->{LEVEL}, " (", $logfuncs{$item}->{DEBUGMASK}, "): ", $1, "\n";
            next OUTER;
        };
    };

    if (eof)
    {
        # reset log function rememberers

#         print "Found functions in $ARGV:\n";
#         foreach my $item (keys %logfuncs)
#         {
#             print "name: $item, level => ", $logfuncs{$item}->{LEVEL}, " mask => ", $logfuncs{$item}->{DEBUGMASK}, "\n";
#         }

        undef %logfuncs;
    }

}
