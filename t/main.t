#!/usr/bin/env perl
use strict;
use warnings FATAL => 'all';

use re '/aa';

use 5.014;

=head1 NAME

t/main.t - which calls the policy reads as a grep used for truth or for its
first element, one call away, and which it leaves alone

=head1 DESCRIPTION

Tables of snippets that must be reported and a table that must not.

A reported call is of a sub in the same file that returns a C<grep>, and the
caller uses only whether the result is empty, or only its first element.  The
edges are the ways of returning a C<grep>, the ways of testing for truth, and
the calls that look the same and are not.

=cut

use Test::More;
use Perl::Critic;

# Loaded so that a syntax error in it is a compile failure here rather than
# Perl::Critic reporting no such policy.  Named as a string below, which is
# what ProhibitUnusedImports cannot see.
use Perl::Critic::Policy::BuiltinFunctions::ProhibitIndirectBooleanGrep;    ## no critic (ProhibitUnusedImports)

# -profile => q{} because Perl::Critic otherwise walks up from cwd looking for a
# .perlcriticrc, finds this dist's own, and runs every policy in it against
# these snippets.  The anchored long name because -single-policy is a pattern.
my $POLICY = '^Perl::Critic::Policy::BuiltinFunctions::ProhibitIndirectBooleanGrep$';

my $critic = Perl::Critic->new( -profile => q{}, '-single-policy' => $POLICY, -severity => 1 );

my $check_table = sub {
    my ( $label, %cases ) = @_;
    foreach my $case ( sort keys %cases ) {
        my ( $expected, $source ) = @{ $cases{$case} };
        is( scalar $critic->critique( \$source ), $expected, "$label: $case" ) or diag $source;
    }
    return;
};

my $SUB = q{sub hits { return grep { $_ > 1 } @_ } };

$check_table->(
    'a sub that returns a grep',
    'with return'               => [ 1, $SUB . q{if ( hits(@x) ) { 1 }} ],
    'as its last statement'     => [ 1, q{sub hits { grep { $_ > 1 } @_ } if ( hits(@x) ) { 1 }} ],
    'a lexical sub'             => [ 1, q{my sub hits { return grep { $_ > 1 } @_ } if ( hits(@x) ) { 1 }} ],
    'a state sub'               => [ 1, q{state sub hits { return grep { $_ > 1 } @_ } if ( hits(@x) ) { 1 }} ],
    'on one of its paths'       => [ 1, q{sub hits { return () unless @_; return grep { $_ > 1 } @_ } if ( hits(@x) ) { 1 }} ],
    'called before its body'    => [ 1, q{if ( hits(@x) ) { 1 } sub hits { return grep { $_ > 1 } @_ }} ],
    'called without parens'     => [ 1, $SUB . q{if ( hits ) { 1 }} ],
    'called once in each place' => [ 2, $SUB . q{if ( hits(@x) ) { 1 } die unless hits(@y);} ],
);

$check_table->(
    'tested for truth',
    'the condition of an if'      => [ 1, $SUB . q{if ( hits(@x) ) { 1 }} ],
    'of an unless'                => [ 1, $SUB . q{unless ( hits(@x) ) { 1 }} ],
    'of an elsif'                 => [ 1, $SUB . q{if ($y) { 1 } elsif ( hits(@x) ) { 2 }} ],
    'of a while'                  => [ 1, $SUB . q{while ( hits(@x) ) { shift @x }} ],
    'negated'                     => [ 1, $SUB . q{my $none = !hits(@x);} ],
    'negated with not'            => [ 1, $SUB . q{my $none = not hits(@x);} ],
    'in a postfix if'             => [ 1, $SUB . q{print 'yes' if hits(@x);} ],
    'in a postfix unless'         => [ 1, $SUB . q{print 'no' unless hits(@x);} ],
    'the condition of a ternary'  => [ 1, $SUB . q{my $say = hits(@x) ? 'yes' : 'no';} ],
    'a ternary that is returned'  => [ 1, $SUB . q{sub say { return hits(@x) ? 'yes' : 'no' }} ],
    'a postfix if on a new line'  => [ 1, $SUB . qq{print 'a long line', 'that goes on'\n    if hits(\@x);} ],
    'one side of && in an if'     => [ 1, $SUB . q{if ( $y && hits(@x) ) { 1 }} ],
    'one side of or in an unless' => [ 1, $SUB . q{unless ( hits(@x) or $y ) { 1 }} ],
    'the left of or, alone'       => [ 1, $SUB . q{hits(@x) or die;} ],
    'grep through a lexical sub'  => [ 1, q{my sub left { return grep { !$out{$_} } @found } while ( left() ) { last }} ],
);

$check_table->(
    'its first element',
    'one variable in a list' => [ 1, $SUB . q{my ($first) = hits(@x);} ],
    'assigned, not declared' => [ 1, $SUB . q{($first) = hits(@x);} ],
);

$check_table->(
    'allowed',
    'in list context'               => [ 0, $SUB . q{my @all = hits(@x);} ],
    'looped over'                   => [ 0, $SUB . q{foreach my $h ( hits(@x) ) { print $h }} ],
    'counted'                       => [ 0, $SUB . q{my $count = hits(@x);} ],
    'counted with scalar'           => [ 0, $SUB . q{if ( scalar( hits(@x) ) > 2 ) { 1 }} ],
    'compared'                      => [ 0, $SUB . q{if ( hits(@x) > 2 ) { 1 }} ],
    'two variables in a list'       => [ 0, $SUB . q{my ( $a1, $a2 ) = hits(@x);} ],
    'a sub that returns a list'     => [ 0, q{sub hits { return @_ } if ( hits(@x) ) { 1 }} ],
    'a sub that returns any'        => [ 0, q{sub hits { return any { $_ > 1 } @_ } if ( hits(@x) ) { 1 }} ],
    'a sub that asks wantarray'     => [ 0, q{sub hits { return wantarray ? grep { $_ } @_ : 0 } if ( hits(@x) ) { 1 }} ],
    'a grep through a variable'     => [ 0, q{sub hits { my @h = grep { $_ } @_; return @h } if ( hits(@x) ) { 1 }} ],
    'a grep inside an inner sub'    => [ 0, q{sub hits { my $f = sub { return grep { $_ } @_ }; return 1 } if ( hits(@x) ) { 1 }} ],
    'a grep in the block of a grep' => [ 0, q{sub hits { return scalar grep { $_ } @_ } if ( hits(@x) ) { 1 }} ],
    'a sub defined elsewhere'       => [ 0, q{if ( hits(@x) ) { 1 }} ],
    'the right of or, alone'        => [ 0, $SUB . q{$y or hits(@x);} ],
    'before a postfix if'           => [ 0, $SUB . q{print hits(@x) if $y;} ],
    'before a postfix if, wrapped'  => [ 0, $SUB . qq{print \$y || hits(\@x)\n    if \$z;} ],
);

$check_table->(
    'the same spelling, another thing',
    'a method'                => [ 0, $SUB . q{if ( $obj->hits(@x) ) { 1 }} ],
    'a hash key'              => [ 0, $SUB . q{if ( $h{hits} ) { 1 }} ],
    'the left of a fat comma' => [ 0, $SUB . q{my %h = ( hits => 1 ); if ( $h{x} ) { 1 }} ],
    'the name of the sub'     => [ 0, $SUB ],
);

done_testing;
