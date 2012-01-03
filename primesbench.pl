#!perl

# Copyright(c) 2011, 2012. David Oswald
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.


# Benchmark implementations of the Sieve of Eratosthenes in Pure Perl,
# Inline::C, Inline::CPP, straight XS, and through an open pipe to
# a C++ compiled program.

# The Sieve of Eratosthenes is used to calculate all primes less than or
# equal to the integer 'n'.  It's one of the fastest algorithms
# available for this task.

# There are implementations that use a standard array sieve, and
# implementations that use a bit vector sieve.

# All subs are tested with Test::More, and benchmarked with Benchmark
# 'cmpthese'.

use strict;
use warnings;
use feature         qw( say );

use Test::More;
use Benchmark       qw( cmpthese );

use Math::Prime::XS qw( primes );

use Inline C   => 'DATA';
use Inline CPP => 'DATA';

#---------------------Subs to test and benchmark -----------------------

my %bench_subs = (
    pure_perl      => \&pure_perl,      # Sieve of Eratos., pure Perl.
#   pure_perl_bvec => \&pure_perl_bvec, # Sieve w/bit vec, pure Perl.
#   pure_pl_merlyn => \&pure_pl_merlyn, # Merlyn bit vec sieve, pure Pl.
#   math_prime_xs  => \&math_prime_xs,  # XS: Math::Prime::XS::primes().
    open_pipe      => \&open_pipe,      # Extrn pipe call: (C++,sieve).
    inline_c_aref  => \&inline_c_aref,  # Inline C, Sieve, rtn aref.
    inline_c_stack => \&inline_c_stack, # Inline C, Sieve, rtn on Stack
    pure_il_c      => \&pure_il_c,      # Inline C, Sieve, direct call.
    pure_il_cpp    => \&pure_il_cpp,    # Inline CPP, BSieve, drct call.
);

# --------------------- Testing Data Sets ------------------------------

my %known_quantities = (
    -5      => 0,       -1      => 0,       0       => 0,
    1       => 0,       2       => 1,       3       => 2,
    5       => 3,       7       => 4,       10      => 4,
    11      => 5,       13      => 6,       19      => 8,
    3_571   => 500,     100_000 => 9_592,   224_737 => 20_000,
);

my %known_primes_lists = (
    -1  =>  [],                     0   =>  [],
    1   =>  [],                     2   =>  [2],
    3   =>  [2,3],                  4   =>  [2,3],
    5   =>  [2,3,5],                6   =>  [2,3,5],
    7   =>  [2,3,5,7],              11  =>  [2,3,5,7,11],
    18  =>  [2,3,5,7,11,13,17],     19  =>  [2,3,5,7,11,13,17,19],
    20  =>  [2,3,5,7,11,13,17,19],
);

# -------------------- Benchmark Data Sets -----------------------------

my $bench_time   = -10;    # - seconds.

my @bench_inputs = ( 2, 500_000, 1_000_000 );
#my @bench_inputs = ( 3_000_000 );

# ----------------------- Run the tests --------------------------------

can_ok( 'main', keys %bench_subs )
    or BAIL_OUT( "can_ok failed.\n" );

while( my ( $name, $sref ) = each %bench_subs ) {
    note "Testing $name.";
    note "\tReturn Value List Sizes";
    while( my ( $n_test, $known_quantity ) = each %known_quantities ) {
        local $Bench::input = $n_test;
        is(  scalar @{ $sref->( ) },  $known_quantity,
             "$name( $n_test ) finds $known_quantity primes."
        ) or BAIL_OUT( "is() failed on $name( $n_test )\n" );
    }
    note"\tReturn Value List Correctness";
    while( my ( $n_test, $listref ) = each %known_primes_lists ) {
        local $Bench::input = $n_test;
        is_deeply(  $sref->( ), $listref,
                    "$name( $n_test ) reports primes of @{$listref}"
        ) or BAIL_OUT( "is_deeply() failed on $name( $n_test ).\n" );
    }
}

done_testing();

# ---------------------- Benchmark the subs ----------------------------

say "\nComparing:\n\t",
    join( "\n\t", sort keys %bench_subs ),
    "\nComparison time: ", -$bench_time, " seconds.";

foreach my $bind_value ( @bench_inputs ) {
    local $Bench::input = $bind_value;
    say "\nInput parameter value of $bind_value";
    cmpthese(
        $bench_time,
        \%bench_subs
    );
}

# ----------------- Here's what we're here to see ----------------------

# Sieve of Eratosthenes, pure Perl -- Array, no bit-vectors.
# Seems to be about the fastest Pure Perl approach I could hone.
sub pure_perl {
    my $top = ( $_[0] // $Bench::input ) + 1;
    return [] if $top < 2;
    my @primes = (1) x $top;
    my $i_times_j;
    for my $i ( 2 .. sqrt $top ) {
        if ( $primes[$i] ) {
            for ( my $j = $i; ( $i_times_j = $i * $j ) < $top; $j++ ) {
                undef $primes[$i_times_j];
            }
        }
    }
    return [ grep { $primes[$_] } 2 .. $#primes ];
}

# Sieve of Eratosthenes, pure Perl -- Bit vector.
# This is about the fastest Perl "vec" solution I could come up with.
sub pure_perl_bvec {
    my $top = ( $_[0] // $Bench::input ) + 1;
    return [ ] if $top < 2;
    my $primes = '';
    vec( $primes, $top, 1 ) = 0;
    my $i_times_j;
    for my $i ( 2 .. sqrt $top ) {
        if ( !vec( $primes, $i, 1 ) ) {
            for ( my $j = $i; ( $i_times_j = $i * $j ) < $top; $j++ ) {
                vec( $primes, $i_times_j, 1 ) = 1;
            }
        }
    }
    return [ grep { !vec( $primes, $_, 1 ) } 2 .. $top-1 ];
}


# Merlyn's Unix Review Column 26, June 1999
# http://www.stonehenge.com/merlyn/UnixReview/col26.html
# Modified to store results in an array rather than print.
# I didn't include this in the presentation benchmark because
# Perl's bit vectors are not fast enough to make it interesting from
# an optimization standpoint.
sub pure_perl_merlyn {
    my $top = ( $_[0] // $Bench::input );
    my $sieve = '';
    my @primes;
    GUESS:
    for ( my $guess = 2 ; $guess <= $top ; $guess++ ) {
        next GUESS if vec( $sieve, $guess, 1 );
        push @primes, $guess;
        for (
            my $mults = $guess * $guess;
            $mults <= $top;
            $mults += $guess
        ){
            vec( $sieve, $mults, 1 ) = 1;
        }
    }
    return \@primes;
}

# A wrapper around the external executable compiled in C++.
# Receives a "big list" of primes via system pipe read.
# Uses Sieve of Eratosthenes implemented in C++.
sub open_pipe {
    my $top = $_[0] // $Bench::input;
    open my $fh, '-|', 'primes.exe ' . $top;
    chomp( my( @primes ) = <$fh> );
    return \@primes;
}


# Thin wrapper to bind input params for the benchmark.
# Inline C, Return array-ref, Sieve of Eratosthenes method.
sub inline_c_aref {
    my $top = $_[0] // $Bench::input;
    return il_c_eratos_primes_av($top);
}


# Using the Math::Prime::XS module for comparison.
# Thin wrapper to achieve bound param, and necessary return type.
sub math_prime_xs {
    my $top = $_[0] // $Bench::input;
    return [  ] if $top < 2;
    return [ primes( $top ) ];
}


# Thin wrapper to bind input params for the benchmark.
# Inline C, Return on stack, Sieve of Eratosthenes method.
sub inline_c_stack {
    my $top = $_[0] // $Bench::input;
    return [ il_c_eratos_primes_stk($top) ];
}


__DATA__



__C__

#include "math.h"


/*
 * Find all primes up to 'search_to' using the Sieve of Eratosthenes.
 * This function returns a big list on The Stack.  Benchmark needs the
 * Perl wrapper to bind the input parameters and convert the returned
 * list to an aref.
 */

void il_c_eratos_primes_stk ( int search_to )
{
    Inline_Stack_Vars;
    Inline_Stack_Reset;
    bool* primes = 0;
    int i;
    if( search_to < 2 )
    {
        Inline_Stack_Done;
        return;
    }
    Newxz( primes, search_to + 1 , bool );
    if( ! primes ) croak( "Failed to allocate memory.\n" );
    for( i = 2; i * i <= search_to; i++ )
        if( !primes[i] )
        {
            int j;
            for( j = i; j * i <= search_to; j++ ) primes[ i * j ] = 1;
        }
    Inline_Stack_Push( sv_2mortal( newSViv(2) ) );
    for( i = 3; i <= search_to; i += 2 )
        if( primes[i] == 0 )
            Inline_Stack_Push( sv_2mortal( newSViv( i ) ) );
    Safefree( primes );
    Inline_Stack_Done;
}


/* Find all primes up to 'search_to' using the Sieve of Eratosthenes.
 * This function returns an array-ref so that the wrapper doesn't have
 * to make the conversion.  But Benchmark still needs a wrapper in
 * order to bind the parameter.
 */

SV* il_c_eratos_primes_av ( int search_to )
{
    AV* av = newAV();
    bool* primes = 0;
    int i;
    if( search_to < 2 ) return newRV_noinc( (SV*) av );
    Newxz( primes, search_to + 1 , bool );
    if( ! primes ) croak( "Failed to allocate memory.\n" );
    for( i = 2; i * i <= search_to; i++ )
        if( !primes[i] )
        {
            int j;
            for( j = i; j * i <= search_to; j++ ) primes[ i * j ] = 1;
        }
    av_push( av, newSViv(2) );
    for( i = 3; i <= search_to; i += 2 )
        if( primes[i] == 0 ) av_push( av, newSViv( i ) );
    Safefree( primes );
    return newRV_noinc( (SV*) av );
}


/* Find all primes up to 'search_to' using the Sieve of Eratosthenes.
 * This function returns an array-ref.
 * Reads the global variable $Bench::input so that a Perl wrapper isn't
 * needed for the benchmark.
 */

SV* pure_il_c()
{
    int search_to = SvIV( get_sv( "Bench::input", 0 ) );
    AV* av = newAV();
    bool* primes = 0;
    int i;
    if( search_to < 2 ) return newRV_noinc( (SV*) av );
    Newxz( primes, search_to + 1 , bool );
    if( ! primes ) croak( "Failed to allocate memory.\n" );
    for( i = 2; i * i <= search_to; i++ )
        if( !primes[i] )
        {
            int j;
            for( j = i; j * i <= search_to; j++ ) primes[ i * j ] = 1;
        }
    av_push( av, newSViv(2) );
    for( i = 3; i <= search_to; i+=2 )
        if( primes[i] == 0 ) av_push( av, newSViv( i ) );
    Safefree( primes );
    return newRV_noinc( (SV*) av );
}



__CPP__

// STL Container classes!
#include <vector>


/* Sieve of Eratosthenes.  Return an array-ref.  Accept global
 * $Bench::input and return an array-ref to eliminate need for Perl
 * benchmark wrapper.
 */


// This turns out to be the fastest approach for inputs beyond 100M.
// Effective up to inputs of about 1.25B.  Beyond that the returned list
// consumes enough memory that there's a lot of swapping slowing it
// it down.

SV* pure_il_cpp()
{
    int search_to = SvIV( get_sv( "Bench::input", 0 ) );
    AV* av = newAV();
    if( search_to < 2 ) return newRV_noinc( (SV*) av );
    std::vector<bool> primes( search_to + 1, 0 );
    for( int i = 2; i * i <= search_to; i++ )
        if( ! primes[i] )
            for( int k, j = i; ( k = i * j ) <= search_to; j++ )
                primes[ k ] = 1;
    av_push( av, newSViv(2) );
    for( int i = 3; i <= search_to; i+=2 )
        if( ! primes[i] ) av_push( av, newSViv(i) );
    return newRV_noinc( (SV*) av );
}
