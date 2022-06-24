my role Containing does Iterator {
    has Iterator $!iterator   is built;
    has Any      $!needle     is built;
    has          $!ignorecase is built;
    has          $!ignoremark is built;
#    has int      $!linenr  is built;  # XXX natives don't work in roles

    method is-lazy() { $!iterator.is-lazy }
}

my class Contains does Containing {
    has Callable $!produce is built;
    has int      $!linenr  is built;

    method pull-one() {
        my $iterator := $!iterator;
        my $needle   := $!needle;

        ++$!linenr
          until (my $line := $iterator.pull-one) =:= IterationEnd
             || $line.contains($needle);

        $line =:= IterationEnd ?? IterationEnd !! $!produce($!linenr++, $line)
    }
}

my class Contains::im does Containing {
    has Callable $!produce is built;
    has int      $!linenr  is built;

    method pull-one() {
        my $iterator   := $!iterator;
        my $needle     := $!needle;
        my $ignorecase := $!ignorecase;
        my $ignoremark := $!ignoremark;

        ++$!linenr
          until (my $line := $iterator.pull-one) =:= IterationEnd
             || $line.contains($needle, :$ignorecase, :$ignoremark);

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

        with $!line -> $line {
            $!line := Str;
            $line
        }
        else {
            ++$!linenr
              until (my $line := $iterator.pull-one) =:= IterationEnd
                 || $line.contains($needle, :$ignorecase, :$ignoremark);

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
    has Callable $!produce is built;
    has int      $!linenr  is built;

    method pull-one() {
        my $iterator := $!iterator;
        my &lookup   := $!needle;

        ++$!linenr
          until (my $line := $iterator.pull-one) =:= IterationEnd
             || lookup($line);

        $line =:= IterationEnd ?? IterationEnd !! $!produce($!linenr++, $line)
    }
}

my class Grep::kv does Containing {
    has int $!linenr is built;
    has Str $!line;

    method pull-one() {
        my $iterator := $!iterator;
        my &lookup   := $!needle;

        with $!line -> $line {
            $!line := Str;
            $line
        }
        else {
            ++$!linenr
              until (my $line := $iterator.pull-one) =:= IterationEnd
                 || lookup($line);

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

my sub produce($p, $k) {
    $p
      ?? -> $linenr, $line { Pair.new: $linenr, $line }
      !! $k
        ?? -> $linenr, $ { $linenr }
        !! -> $, $line { $line }
}

proto sub lines-containing(|) is export {*}
multi sub lines-containing(
  Iterator:D  $iterator,
       Any:D  $needle,
             :$p,
             :$k,
             :$kv,
             :$v,
             :i(:$ignorecase),
             :m(:$ignoremark),
             :offset($linenr) = 0,
             :$max-count,
--> Seq:D) {
    my $seq := Seq.new: Callable.ACCEPTS($needle) && !Regex.ACCEPTS($needle)
      ?? $kv
        ?? Grep::kv.new(
             :$iterator, :$needle, :$linenr
           )
        !! Grep.new(
             :$iterator, :$needle, :produce(produce($p, $k)), :$linenr
           )
      !! $kv
        ?? Contains::kv.new(
             :$iterator, :$needle, :$ignorecase, :$ignoremark, :$linenr
           )
        !! $ignorecase || $ignoremark
          ?? Contains::im.new(
               :$iterator, :$needle, :produce(produce($p, $k)), :$linenr
               :$ignorecase, :$ignoremark
             )
          !! Contains.new(
               :$iterator, :$needle, :produce(produce($p, $k)), :$linenr
             );

    $max-count.defined ?? $seq.head($max-count) !! $seq
}
multi sub lines-containing(Seq:D $seq, Any:D $needle, *%_ --> Seq:D) {
    lines-containing($seq.iterator, $needle, |%_)
}
multi sub lines-containing(@lines, Any:D $needle, *%_ --> Seq:D) {
    lines-containing(@lines.iterator, $needle, |%_)
}
multi sub lines-containing(
        %map,
  Any:D $needle,
  :$p, :$k, :$kv, :$v, :i(:$ignorecase), :m(:$ignoremark), :$offset = 0
--> Seq:D) {
    my &producer := produce($p, $k);

    # NOTE: this depends on a hash producing keys and values in the
    # same order if the hash is unchanged
    my @keys = %map.keys;
    lines-containing(
      %map.values.iterator, $needle, :p, :$ignorecase, :$ignoremark, :$offset
    ).map: {
        producer @keys.AT-POS(.key), .value
    }
}
multi sub lines-containing(Any:D $source, Any:D $needle, *%_ --> Seq:D) {
    lines-containing($source.lines(:enc<utf8-c8>).iterator, $needle, |%_)
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

=end code

=head1 DESCRIPTION

Lines::Containing exports a single subroutine C<lines-containing> that can
either take a C<Seq> or C<Iterator> producing lines, an array with lines,
a C<Hash> (or C<Map>) with lines as values, or any other object that supports
a C<lines> method producing lines (such as C<Str>, C<IO::Path>, C<IO::Handle>,
C<Supply>) as the source to check.

As the second parameter, it takes either a C<Cool> object, a regular
expression, or a C<Callable> as the needle to search for.

It returns a (potentially lazy) C<Seq> of the lines that contained the
needle.

Additionally, it supports the following named arguments:

=item :p

Produce C<Pair>s with the line number (or the key in case of a C<Hash>) as
the key.

=item :k

Produce line numbers only, or keys only in case of a C<Hash>.

=item :kv

Produce line number (or key in case of a C<Hash>) and line alternately.

=item :v (default)

Produce lines only.

=item :i or :ignorecase

Ignore case (only if the needle is a C<Str>).

=item :m or :ignoremark

Ignore mark (only if the needle is a C<Str>).

=item :max-count

Maximum number of matches that will be produced.  Defaults to C<Any>,
which indicates that B<all> matches must be produced.

=item :offset

The line number of the first line in the source (defaults to B<0>).

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
