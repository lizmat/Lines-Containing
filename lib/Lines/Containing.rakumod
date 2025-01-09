use has-word:ver<0.0.6+>:auth<zef:lizmat>;

my role Containing does Iterator {
    has Iterator $!iterator   is built(:bind);
    has Any      $!needle     is built(:bind);
    has          $!target     is built(:bind);
    has          $!ignorecase is built(:bind);
    has          $!ignoremark is built(:bind);
#    has int      $!linenr  is built;  # XXX natives don't work in roles

    method is-lazy() { $!iterator.is-lazy }
}

my class Contains does Containing {
    has Callable $!produce is built(:bind);
    has int      $!linenr  is built;

    method pull-one() {
        my $iterator := $!iterator;
        my $needle   := $!needle;
        my $target   := $!target;

        ++$!linenr
          until (my $line := $iterator.pull-one) =:= IterationEnd
             || $line.contains($needle) =:= $target;

        $line =:= IterationEnd ?? IterationEnd !! $!produce($!linenr++, $line)
    }
}

my class Contains::im does Containing {
    has Callable $!produce is built(:bind);
    has int      $!linenr  is built;

    method pull-one() {
        my $iterator   := $!iterator;
        my $needle     := $!needle;
        my $ignorecase := $!ignorecase;
        my $ignoremark := $!ignoremark;
        my $target     := $!target;

        ++$!linenr
          until (my $line := $iterator.pull-one) =:= IterationEnd
           || $line.contains($needle,:$ignorecase,:$ignoremark) =:= $target;

        $line =:= IterationEnd ?? IterationEnd !! $!produce($!linenr++, $line)
    }
}

my class Contains::kv does Containing {
    has int $!linenr is built;
    has Str $!line;

    method pull-one() {
        my $iterator   := $!iterator;
        my $needle     := $!needle;
        my $ignorecase := $!ignorecase;
        my $ignoremark := $!ignoremark;
        my $target     := $!target;

        with $!line -> $line {
            $!line := Str;
            $line
        }
        else {
            ++$!linenr
              until (my $line := $iterator.pull-one) =:= IterationEnd
               || $line.contains($needle,:$ignorecase,:$ignoremark) =:= $target;

            if $line =:= IterationEnd {
                IterationEnd
            }
            else {
                $!line := $line;
                $!linenr++
            }
        }
    }
}

my class Grep does Containing {
    has Callable $!produce is built(:bind);
    has int      $!linenr  is built;

    method pull-one() {
        my $iterator := $!iterator;
        my &lookup   := $!needle;
        my $target   := $!target;

        ++$!linenr
          until (my $line := $iterator.pull-one) =:= IterationEnd
             || (my $result := lookup($line)) =:= $target
             || $result =:= Empty
             || !Bool.ACCEPTS($result);

        $line =:= IterationEnd
          ?? IterationEnd
          !! $!produce(
               $!linenr++,
               $result =:= Empty || Bool.ACCEPTS($result) ?? $line !! $result
             )
    }
}

my class Grep::kv does Containing {
    has int $!linenr is built;
    has Str $!line;

    method pull-one() {
        my $iterator := $!iterator;
        my &lookup   := $!needle;
        my $target   := $!target;

        with $!line -> $line {
            $!line := Str;
            $line
        }
        else {
            ++$!linenr
              until (my $line := $iterator.pull-one) =:= IterationEnd
                 || (my $result := lookup($line)) =:= $target
                 || $result =:= Empty
                 || !Bool.ACCEPTS($result);

            if $line =:= IterationEnd {
                IterationEnd
            }
            else {
                $!line := $result =:= Empty || Bool.ACCEPTS($result)
                  ?? $line
                  !! $result;
                $!linenr++
            }
        }
    }
}

my sub is-simple-Callable($needle) {
    Callable.ACCEPTS($needle) && !Regex.ACCEPTS($needle)
}

my sub produce($p, $k) {
    $p
      ?? -> $linenr, $line { Pair.new: $linenr, $line }
      !! $k
        ?? -> $linenr, $ { $linenr }
        !! -> $, $line { $line }
}

proto sub lines-containing(|) {*}
multi sub lines-containing(
  Iterator:D  $iterator,
       Any:D  $needle,
             :$p,
             :$k,
             :$kv,
             :v($),
             :i(:$ignorecase),
             :m(:$ignoremark),
             :$invert-match,
             :offset($linenr) = 0,
             :$max-count,
             :$count-only,
) {
    my $target := !$invert-match;

    # Only want to know number of lines with needle
    if $count-only {
        my $produce := produce(False, True);
        my $counter := is-simple-Callable($needle)
          ?? Grep.new(:$iterator, :$needle, :$produce, :$linenr, :$target)
          !! $ignorecase || $ignoremark
            ?? Contains::im.new(
                 :$iterator, :$needle, :$produce, :$linenr, :$target,
                 :$ignorecase, :$ignoremark
             )
            !! Contains.new(
                 :$iterator, :$needle, :$produce, :$linenr, :$target
               );
        my int $count;
        if $max-count {
            ++$count
              until $counter.pull-one =:= IterationEnd || $count == $max-count;
        }
        else {
            ++$count
              until $counter.pull-one =:= IterationEnd;
        }
        $count
    }

    # Want to know the actual lines
    else {
        my $seq := Seq.new: is-simple-Callable($needle)
          ?? $kv
            ?? Grep::kv.new(
                 :$iterator, :$needle,
                 :$linenr, :$target
               )
            !! Grep.new(
                 :$iterator, :$needle,
                 :produce(produce($p, $k)), :$linenr, :$target
               )
          !! $kv
            ?? Contains::kv.new(
                 :$iterator, :$needle,
                 :$linenr, :$target
                 :$ignorecase, :$ignoremark,
               )
            !! $ignorecase || $ignoremark
              ?? Contains::im.new(
                   :$iterator, :$needle,
                   :produce(produce($p, $k)), :$linenr, :$target,
                   :$ignorecase, :$ignoremark
                 )
              !! Contains.new(
                   :$iterator, :$needle,
                   :produce(produce($p, $k)), :$linenr, :$target
                 );

        $max-count.defined ?? $seq.head($max-count) !! $seq
    }
}
multi sub lines-containing(Seq:D $seq, Any:D $needle, *%_) {
    lines-containing($seq.iterator, $needle, |%_)
}
multi sub lines-containing(@lines, Any:D $needle, *%_) {
    lines-containing(@lines.iterator, $needle, |%_)
}
multi sub lines-containing(
         %map,
  Any:D  $needle,
        :$p,
        :$kv,
        :$k,
        :v($),
        :$count-only,
        *%_
) {
    if $count-only {
        my int $count;
        ++$count for lines-containing(%map.values.iterator, $needle, :k, |%_);
        $count
    }
    else {
        my &producer := produce($p, $k);

        # NOTE: this depends on a hash producing keys and values in the
        # same order if the hash is unchanged
        my @keys = %map.keys;
        lines-containing(%map.values.iterator, $needle, :p, |%_).map: {
            producer @keys.AT-POS(.key), .value
        }
    }
}
multi sub lines-containing(Any:D $source, Any:D $needle, :$type, *%_) {
    lines-containing(
      $source.lines(:enc<utf8-c8>).iterator,
      !$type || $type eq 'contains'
        ?? $needle
        !! $type eq 'words'
          ?? { has-word $_, $needle }
          !! $type eq 'starts-with'
            ?? *.starts-with($needle)
            !! $type eq 'ends-with'
              ?? *.ends-with($needle)
              !! (die "Unrecognized type: $type"),
      |%_
    )
}

sub EXPORT() {
    Map.new: (
      '&lines-containing' => &lines-containing,
      '&has-word'         => &has-word,
    )
}

=begin pod

=head1 NAME

Lines::Containing - look for lines containing a given needle

=head1 SYNOPSIS

=begin code :lang<raku>

use Lines::Containing;

# lines with an "a"
.say for lines-containing("foo\nbar\nbaz", "a")  # bar␤baz␤

# lines ending on "r", with their line number
.say for lines-containing("foo\nbar\nbaz", / r $/, :kv);  # 1␤bar␤

# line numbers of lines starting with "f", starting at 1
.say for lines-containing("foo\nbar", *.starts-with("b"), :k, :offset(1));  # 2␤

# number of lines starting with "b", with their line number
.say for lines-containing("foo\nbar\nbaz", *.starts-with("b"), :count-only);  # 2␤

=end code

=head1 DESCRIPTION

Lines::Containing provides a single subroutine C<lines-containing> that
allows searching for a string in an object that can produce something
akin to lines of text.

=head1 EXPORTED SUBROUTINES

=head2 lines-containing

The C<lines-containing> subroutine can either take a C<Seq> or C<Iterator>
producing lines, an array with lines, a C<Hash> (or C<Map>) with lines as
values, or any other object that supports a C<lines> method producing
lines (such as C<Str>, C<IO::Path>, C<IO::Handle>, C<Supply>) as the
source to check.

As the second parameter, it takes either a C<Cool> object, a regular
expression, or a C<Callable> as the needle to search for.

It returns a (potentially lazy) C<Seq> of the lines that contained the
needle.

If a C<Callable> was specified as the second parameter, then the following
rules apply:

=item if Bool was returned

Produce if C<True>, or if C<:invert-match> is specified, if C<False>.

=item if Empty was returned

Always produce the original line.

=item anything else

Produce whatever was returned by the C<Callable> otherwise.

Additionally, it supports the following named arguments:

=item :count-only

Only produce a count of lines that have a match.

=item :k

Produce line numbers only, or keys only in case of a C<Hash>.

=item :kv

Produce line number (or key in case of a C<Hash>) and line alternately.

=item :i or :ignorecase

Ignore case (only if the needle is a C<Str>).

=item :invert-match

Only produce lines that do B<NOT> match.

=item :m or :ignoremark

Ignore mark (only if the needle is a C<Str>).

=item :max-count=N

Maximum number of matches that will be produced.  Defaults to C<Any>,
which indicates that B<all> matches must be produced.

=item :offset=N

The line number of the first line in the source (defaults to B<0>).

=item :p

Produce C<Pair>s with the line number (or the key in case of a C<Hash>) as
the key.

=item :type=words|starts-with|ends-with|contains

Only makes sense if the needle is a C<Cool> object.  With C<words>
specified, will look for needle as a word in a line, with C<starts-with>
will look for the needle at the beginning of a line, with C<ends-with>
will look for the needle at the end of a line, with C<contains> will
look for the needle at any position in a line.  Which is the default.

=item :v (default)

Produce lines only.

=head2 has-word

The C<has-word> subroutine, as provided by the version of
L<has-word|https://raku.land/zef:lizmat/has-word> that is used.

=head1 AUTHOR

Elizabeth Mattijsen <liz@raku.rocks>

Source can be located at: https://github.com/lizmat/Lines-Containing .
Comments and Pull Requests are welcome.

If you like this module, or what I’m doing more generally, committing to a
L<small sponsorship|https://github.com/sponsors/lizmat/>  would mean a great
deal to me!

=head1 COPYRIGHT AND LICENSE

Copyright 2022 Elizabeth Mattijsen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod

# vim: expandtab shiftwidth=4
