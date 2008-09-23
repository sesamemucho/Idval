#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Idval' );
}

diag( "Testing Idval $Idval::VERSION, Perl $], $^X" );
