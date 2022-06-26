[![Actions Status](https://github.com/lizmat/Lines-Containing/actions/workflows/test.yml/badge.svg)](https://github.com/lizmat/Lines-Containing/actions)

NAME
====

Lines::Containing - look for lines containing a given needle

SYNOPSIS
========

```raku
use Lines::Containing;

# lines with an "a"
.say for lines-containing("foo\nbar\nbaz", "a")  # bar␤baz␤

# lines ending on "r", with their line number
.say for lines-containing("foo\nbar\nbaz", / r $/, :kv);  # 1␤bar␤

# line numbers of lines starting with "f", starting at 1
.say for lines-containing("foo\nbar", *.starts-with("b"), :k, :offset(1));  # 2␤
```

DESCRIPTION
===========

Lines::Containing exports a single subroutine `lines-containing` that can either take a `Seq` or `Iterator` producing lines, an array with lines, a `Hash` (or `Map`) with lines as values, or any other object that supports a `lines` method producing lines (such as `Str`, `IO::Path`, `IO::Handle`, `Supply`) as the source to check.

As the second parameter, it takes either a `Cool` object, a regular expression, or a `Callable` as the needle to search for.

It returns a (potentially lazy) `Seq` of the lines that contained the needle.

If a `Callable` was specified as the second parameter, then the following rules apply:

  * if Bool was returned

Produce if `True`, or if `:invert-match` is specified, if `False`.

  * if Empty was returned

Always produce the original line.

  * anything else

Produce whatever was returned by the `Callable` otherwise.

Additionally, it supports the following named arguments:

  * :p

Produce `Pair`s with the line number (or the key in case of a `Hash`) as the key.

  * :k

Produce line numbers only, or keys only in case of a `Hash`.

  * :kv

Produce line number (or key in case of a `Hash`) and line alternately.

  * :v (default)

Produce lines only.

  * :i or :ignorecase

Ignore case (only if the needle is a `Str`).

  * :invert-match

Only produce lines that do **NOT** match.

  * :m or :ignoremark

Ignore mark (only if the needle is a `Str`).

  * :max-count

Maximum number of matches that will be produced. Defaults to `Any`, which indicates that **all** matches must be produced.

  * :offset

The line number of the first line in the source (defaults to **0**).

AUTHOR
======

Elizabeth Mattijsen <liz@raku.rocks>

Source can be located at: https://github.com/lizmat/Lines-Containing . Comments and Pull Requests are welcome.

If you like this module, or what I’m doing more generally, committing to a [small sponsorship](https://github.com/sponsors/lizmat/) would mean a great deal to me!

COPYRIGHT AND LICENSE
=====================

Copyright 2022 Elizabeth Mattijsen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

