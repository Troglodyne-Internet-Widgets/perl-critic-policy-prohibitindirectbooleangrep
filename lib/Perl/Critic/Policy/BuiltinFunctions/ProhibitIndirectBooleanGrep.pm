package Perl::Critic::Policy::BuiltinFunctions::ProhibitIndirectBooleanGrep;

# ABSTRACT: Use any or first, not a sub that returns a grep, for truth or the first match.

use strict;
use warnings FATAL => 'all';
use 5.014;
use re '/aa';
use Readonly;
use List::Util          qw{any first};
use Perl::Critic::Utils qw{ :severities };

use parent qw{Perl::Critic::Policy};

=head1 DESCRIPTION

C<BuiltinFunctions::ProhibitBooleanGrep> reports a C<grep> whose result is
only tested for truth, because C<any> from L<List::Util> stops at the first
match and the C<grep> reads the whole list.  It cannot see the same C<grep>
one call away:

    my sub waiting { return grep { !$out{$_} } @found }
    ...
    while ( waiting() ) { ... }    # reported

This policy reports such a call.  The sub is defined in the same file, and its
result is a C<grep>: the value of a C<return>, or its last statement.  The call
is reported where the caller uses only whether the result is empty, and where
it uses only the first element, which C<first> finds without reading the rest:

    my ($next) = waiting();        # reported

The report is at the call and not at the sub, because the same sub can be
right for a caller that wants the list.  The fix is usually a second sub, or
C<any> or C<first> at the call.

=head2 Truth

A call is tested for truth when it is, or is an operand of C<!>, C<not>,
C<&&>, C<||>, C<and> or C<or> inside, the condition of C<if>, C<elsif>,
C<unless>, C<while> or C<until>, of a postfix modifier, or of a ternary.  So is
a call under C<!> or C<not> anywhere, and the left operand of C<and>, C<or>,
C<&&> or C<||> that starts a statement, such as C<check() or die>.

=head2 What it leaves alone

A call in list context, a count, a comparison, or a call through
C<scalar()>.  A sub that asks C<wantarray>, because it chooses its own result
for scalar context.  A C<grep> that reaches the return through a variable, and
one inside an inner anonymous sub.  A method call, because the method that
runs can be another sub of the same name.  A sub defined in another file,
because Perl::Critic gives a policy one file.  A C<map>, for which there is no
C<any> to use instead.

=head1 CONFIGURATION

This Policy is not configurable except for the standard options.

=cut

Readonly::Scalar my $DESC_TRUTH => q{A sub that returns a grep, tested for truth};
Readonly::Scalar my $EXPL_TRUTH => q{Use List::Util::any, which stops at the first match};
Readonly::Scalar my $DESC_FIRST => q{A sub that returns a grep, for its first element};
Readonly::Scalar my $EXPL_FIRST => q{Use List::Util::first, which stops at the first match};

Readonly::Hash my %CONDITIONAL => map { $_ => 1 } qw{ if elsif unless while until };
Readonly::Hash my %NEGATION    => map { $_ => 1 } qw{ ! not };
Readonly::Hash my %LOGICAL     => map { $_ => 1 } qw{ && || and or };

=head2 METHODS

=head3 supported_parameters

=head3 default_severity

=head3 default_themes

=head3 applies_to

The whole document, because a call can come before the sub that it calls.

=head3 violates

=cut

sub supported_parameters { return () }
sub default_severity     { return $SEVERITY_LOW }
sub default_themes       { return qw{ performance } }
sub applies_to           { return 'PPI::Document' }

# Whether the significant children of a block end in a grep that is its value:
# a return of one anywhere in the body, or one as the last statement.  Not one
# inside an inner sub, whose returns are its own.
my $returns_grep = sub {
    my ($block) = @_;

    my $inner = sub {
        my ($elem) = @_;
        for ( my $up = $elem->parent; $up && $up != $block; $up = $up->parent ) {
            return 1 if $up->isa('PPI::Statement::Sub') || ( $up->isa('PPI::Structure::Block') && ( $up->sprevious_sibling // q{} ) eq 'sub' );
        }
        return 0;
    };
    my $starts_grep = sub {
        my ( $statement, $skip ) = @_;
        my @parts = $statement->schildren;
        shift @parts if $skip;
        return @parts && $parts[0]->isa('PPI::Token::Word') && $parts[0]->content eq 'grep';
    };

    my $returns = $block->find( sub { $_[1]->isa('PPI::Statement::Break') && ( $_[1]->schild(0) // q{} ) eq 'return' } ) || [];
    return 1 if any { !$inner->($_) && $starts_grep->( $_, 1 ) } @$returns;

    my $last = ( grep { $_->isa('PPI::Statement') } $block->schildren )[-1];
    return $last && ref $last eq 'PPI::Statement' && $starts_grep->( $last, 0 );
};

# The subs of the document whose value is a grep, by name.
my $grep_subs = sub {
    my ($doc) = @_;
    my %found;
    foreach my $sub ( @{ $doc->find('PPI::Statement::Sub') || [] } ) {
        my $block = $sub->block or next;
        next                     if $block->find_any( sub { $_[1]->isa('PPI::Token::Word') && $_[1]->content eq 'wantarray' } );
        $found{ $sub->name } = 1 if $returns_grep->($block);
    }
    return \%found;
};

# Whether a word is a call of a sub by that name, and not a method, a hash key,
# the left of a fat comma, or the name in a sub statement.
my $is_call = sub {
    my ($word) = @_;
    my $parent = $word->parent;
    return 0 if $parent->isa('PPI::Statement::Sub');
    my $before = $word->sprevious_sibling;
    return 0 if $before && $before->isa('PPI::Token::Operator') && $before->content eq '->';
    my $after = $word->snext_sibling;
    return 0 if $after          && $after->isa('PPI::Token::Operator')               && $after->content eq '=>';
    return 0 if $parent->parent && $parent->parent->isa('PPI::Structure::Subscript') && $parent->schildren == 1;
    return 1;
};

# The call as an operand: the word, and its argument list when it has one.
my $operand_end = sub {
    my ($word) = @_;
    my $after = $word->snext_sibling;
    return $after && $after->isa('PPI::Structure::List') ? $after : $word;
};

# Whether the siblings of a call, within its own statement, are only the
# logical operators and negations that test it for truth.
my $only_logic = sub {
    my ( $word, $end ) = @_;
    my $statement = $word->parent;
    foreach my $part ( $statement->schildren ) {
        next     if $part == $word || $part == $end;
        next     if $part->isa('PPI::Token::Operator') && ( $LOGICAL{ $part->content } || $NEGATION{ $part->content } );
        next     if $part->isa('PPI::Token::Word')     && ( $LOGICAL{ $part->content } || $NEGATION{ $part->content } );
        next     if $part->isa('PPI::Token::Symbol') || $part->isa('PPI::Structure::List');
        return 0 if $part->isa('PPI::Token::Operator');
    }
    return 1;
};

# Whether everything between the modifier and the call is logic and operands.
my $only_logic_after = sub {
    my ( $parts, $from, $to ) = @_;
    foreach my $part ( @{$parts}[ $from + 1 .. $to - 1 ] ) {
        next     if $LOGICAL{ $part->content } || $NEGATION{ $part->content };
        return 0 if $part->isa('PPI::Token::Operator');
    }
    return 1;
};

# How the caller uses the result: 'truth', 'first', or nothing.
my $use_of = sub {
    my ($word)    = @_;
    my $end       = $operand_end->($word);
    my $before    = $word->sprevious_sibling;
    my $statement = $word->parent;

    # The semicolon that ends the statement is not a thing after the call.
    my $after = $end->snext_sibling;
    undef $after if $after && $after->isa('PPI::Token::Structure') && $after->content eq ';';

    return 'truth' if $before && $NEGATION{ $before->content };
    return 'truth' if $after && $after->content eq '?' && ( !$before || $before->content eq '=' || $before->content eq 'return' );

    # In a condition, alone or among logical operators.
    my $holder = $statement->parent;
    return 'truth' if $holder && $holder->isa('PPI::Structure::Condition') && $only_logic->( $word, $end );

    # After a postfix modifier, to the end of the statement.  By place among
    # the parts of the statement, because a statement can wrap.
    my @parts    = $statement->schildren;
    my ($at)     = grep { $parts[$_] == $word } 0 .. $#parts;
    my $modifier = first { $_ > 0 && $parts[$_]->isa('PPI::Token::Word') && $CONDITIONAL{ $parts[$_]->content } } 0 .. $at - 1;
    return 'truth' if defined $modifier && ( $before == $parts[$modifier] || ( $LOGICAL{ $before->content } && $only_logic_after->( \@parts, $modifier, $at ) ) );

    # The left of a logical operator that starts the statement, as in a
    # check followed by or die.
    return 'truth' if !$before && $after && $LOGICAL{ $after->content } && $statement->schild(0) == $word;

    # A list of one scalar on the left of the assignment, declared or not.
    if ( $before && $before->content eq '=' && !$after ) {
        my $target = $before->sprevious_sibling;
        if ( $target && $target->isa('PPI::Structure::List') ) {
            my @symbols = @{ $target->find('PPI::Token::Symbol') || [] };
            return 'first' if @symbols == 1 && $symbols[0]->raw_type eq '$';
        }
    }
    return;
};

sub violates {
    my ( $self, undef, $doc ) = @_;

    my $subs = $grep_subs->($doc);
    return if !%$subs;

    my @violations;
    foreach my $word ( @{ $doc->find('PPI::Token::Word') || [] } ) {
        next if !$subs->{ $word->content } || !$is_call->($word);
        my $use = $use_of->($word) or next;
        push @violations, $use eq 'first'
          ? $self->violation( $DESC_FIRST, $EXPL_FIRST, $word )
          : $self->violation( $DESC_TRUTH, $EXPL_TRUTH, $word );
    }
    return @violations;
}

1;
