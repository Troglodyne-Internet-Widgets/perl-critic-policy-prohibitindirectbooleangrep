# NAME

Perl::Critic::Policy::BuiltinFunctions::ProhibitIndirectBooleanGrep - Use any or first, not a sub that returns a grep, for truth or the first match.

# VERSION

version 0.001

# DESCRIPTION

`BuiltinFunctions::ProhibitBooleanGrep` reports a `grep` whose result is
only tested for truth, because `any` from [List::Util](https://metacpan.org/pod/List%3A%3AUtil) stops at the first
match and the `grep` reads the whole list.  It cannot see the same `grep`
one call away:

```perl
my sub waiting { return grep { !$out{$_} } @found }
...
while ( waiting() ) { ... }    # reported
```

This policy reports such a call.  The sub is defined in the same file, and its
result is a `grep`: the value of a `return`, or its last statement.  The call
is reported where the caller uses only whether the result is empty, and where
it uses only the first element, which `first` finds without reading the rest:

```perl
my ($next) = waiting();        # reported
```

The report is at the call and not at the sub, because the same sub can be
right for a caller that wants the list.  The fix is usually a second sub, or
`any` or `first` at the call.

## Truth

A call is tested for truth when it is, or is an operand of `!`, `not`,
`&&`, `||`, `and` or `or` inside, the condition of `if`, `elsif`,
`unless`, `while` or `until`, of a postfix modifier, or of a ternary.  So is
a call under `!` or `not` anywhere, and the left operand of `and`, `or`,
`&&` or `||` that starts a statement, such as `check() or die`.

## What it leaves alone

A call in list context, a count, a comparison, or a call through
`scalar()`.  A sub that asks `wantarray`, because it chooses its own result
for scalar context.  A `grep` that reaches the return through a variable, and
one inside an inner anonymous sub.  A method call, because the method that
runs can be another sub of the same name.  A sub defined in another file,
because Perl::Critic gives a policy one file.  A `map`, for which there is no
`any` to use instead.

# CONFIGURATION

This Policy is not configurable except for the standard options.

## METHODS

### supported\_parameters

### default\_severity

### default\_themes

### applies\_to

The whole document, because a call can come before the sub that it calls.

### violates

# AUTHORS

Current Maintainers:

- George S. Baugh <george@troglodyne.net>

# COPYRIGHT AND LICENSE

Copyright (c) 2026 Troglodyne LLC

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
