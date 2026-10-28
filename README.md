# x-grep

<p align="center"><img src="docs/bitwise-banner.svg" alt="x-grep, with Bitwise the owl" width="100%"></p>

POSIX grep on x-lang, the second tool of the self-hosting arc (x-awk is
the first; x-lang's `docs/bootstrap-closure.md` measured grep as the
build's single most-invoked external, 4,186 calls).  BRE by default
with the escape-swap translated onto `lib/x/type/regex.x` -- `\( \)
\{ \}` and the `\| \+ \?` that GNU, BSD and busybox grep all take as
operators, the bare characters literal -- `-E` for the engine's native
ERE-like dialect, `-F` for fixed strings.

Status: pre-release.  Working: every option busybox 1.36.1's grep
takes -- `-H -h -n -l -L -c -o -q -v -s -r -R -i -w -x -F -E`, `-m N`,
`-A -B -C N` -- with `-e`/`-f` pattern collection, bundled short flags,
`--`, files with the more-than-one prefix rule, `-` and default stdin,
and the status contract (0 match, 1 none, 2 trouble).  x-grep is the
middle ground between GNU, BSD and busybox grep, on portable idioms:
where the three differ, the common ground of GNU and BSD wins, and every
spec expectation comes from a real grep run.  `[:named:]` classes expand
in BRE and ERE.  Refused
loudly: back-references.  Divergence inherited from the engine:
leftmost-first matching where POSIX wants leftmost-longest -- invisible
to selection, visible under `-o` when one alternative is a prefix of
another (`-oE 'a|ab'` prints `a` where busybox prints `ab`).

Paired with x-lang v0.39.0 (`lang.xon` is the checkable row).

## Try it

    make install        # into the x on PATH

    x -l grep -- [-HhnlLoqvsrRiwFE] [-m N] [-A|B|C N] [-e pat]... [-f patfile]... [pat] [file]...

    printf 'aa\nbb\n' | x -l grep 'a'
    x -l grep -- -in pattern file1 file2
    x -l grep -q needle haystack.txt; echo $?

The `--` lets grep's own options through x.sh's parsing; without it,
place options after the pattern.  The pure core is
`(grep-run ARGV INPUT-TEXT)` -- the suite drives it directly, with
every expectation taken from a real grep run.

## Tests

    make test           # the suite, loud on any failure
    make check          # judged against tests/contract/known-failures.txt

## Layout

    lang.xon          what this bundle IS (lang, dialect, pairing, entry)
    run.x             the entry: seam globals, and operands mean "be grep"
    grep/prims.x      the platform layer (byte doors and File, one file)
    grep/bre.x        BRE/-i/[:classes:] compiled into engine patterns; the -w, -x and -o loops
    grep/core.x       options, the line loop, the status
    grep/cli.x        stdin reclaim, grep-main (the exit)
    tests/            markdown specs + the platform's runner, vendored nowhere

<p align="center"><img src="docs/bitwise-mark.svg" alt="Bitwise" width="96"></p>
