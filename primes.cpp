

#include <iostream>
#include <cstdlib>
#include <vector>

using namespace std;

// The first 500 primes are found from 2 to 3571.

const int TOP = 3571;

// http://en.wikipedia.org/wiki/List_of_prime_numbers
// Uses sieve of eratos approach.

int main( int argc, char *argv[] ) {
    int search_to = ( argc > 1 ) ? atoi( argv[1] ) : TOP;
    if( search_to < 2 ) return 0;
    vector<bool> primes( search_to + 1 );

    for( int i = 2; i * i <= search_to; i++ )
        if( ! primes[i] )
            for( int k, j = i; ( k = i * j ) <= search_to; j++ )
                primes[ k ] = 1;

    cout << 2 << endl;
    for( int i = 3; i <= search_to; i+=2 )
        if( ! primes[i] ) cout << i << endl;

    return 0;
}
