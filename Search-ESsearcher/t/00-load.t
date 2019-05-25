#!perl -T
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'Search::ESsearcher' ) || print "Bail out!\n";
}

diag( "Testing Search::ESsearcher $Search::ESsearcher::VERSION, Perl $], $^X" );
