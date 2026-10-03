# @weight 1

The command line, as busybox's grep reads it: `--help` first prints the help
text on stdout, and 0; an option grep does not take is refused in musl
getopt's words, then the usage text, on stderr, and 2; no pattern at all is
the usage text alone, and 2.  The text is busybox's, less the banner line and
the rows for the options this grep does not take (-H -h -L -o -r -R -m -A -B
-C).  Options stop at the first operand, as musl's getopt stops.  A case
prints stdout, then `stderr:` and what grep wrote there, then the status.

## the fixture

### a run of grep with its stderr, and a pattern file

```grep
(def %cli-err "/tmp/x-grep-cli.err")
(def %cli-pats "/tmp/x-grep-cli.pats")
(file-close (let ((fd (file-open-write %cli-pats))) (do (file-write fd "b\nzz\n") fd)))
(def run (fn (_ argv input) (do (sys-dup2 2 8) (def e (file-open-write %cli-err)) (sys-dup2 e 2) (def st (grep-run argv input)) (sys-dup2 8 2) (file-close e) (display "stderr:\n") (display (file-read-all %cli-err)) (display "status ") (display st) (newline))))
(display "made")
```
---
    made

## help

### --help prints busybox's text on stdout, and 0

```grep
(run (list "--help") "")
```
---
```output
Usage: grep [-HhnlLoqvsrRiwFE] [-m N] [-A|B|C N] { PATTERN | -e PATTERN... | -f FILE... } [FILE]...

Search for PATTERN in FILEs (or stdin)

	-n	Add 'line_no:' prefix
	-l	Show only names of files that match
	-c	Show only count of matching lines
	-q	Quiet. Return 0 if PATTERN is found, 1 otherwise
	-s	Suppress open and read errors
	-v	Select non-matching lines
	-i	Ignore case
	-w	Match whole words only
	-x	Match whole lines only
	-F	PATTERN is a literal (not regexp)
	-E	PATTERN is an extended regexp
	-e PTRN	Pattern to match
	-f FILE	Read pattern from file
stderr:
status 0
```

## refusals

### a letter grep does not take, alone and in a cluster

```grep
(do (run (list "-Q" "a") "") (run (list "-cQ" "a") ""))
```
---
```output
stderr:
grep: unrecognized option: Q
Usage: grep [-HhnlLoqvsrRiwFE] [-m N] [-A|B|C N] { PATTERN | -e PATTERN... | -f FILE... } [FILE]...

Search for PATTERN in FILEs (or stdin)

	-n	Add 'line_no:' prefix
	-l	Show only names of files that match
	-c	Show only count of matching lines
	-q	Quiet. Return 0 if PATTERN is found, 1 otherwise
	-s	Suppress open and read errors
	-v	Select non-matching lines
	-i	Ignore case
	-w	Match whole words only
	-x	Match whole lines only
	-F	PATTERN is a literal (not regexp)
	-E	PATTERN is an extended regexp
	-e PTRN	Pattern to match
	-f FILE	Read pattern from file
status 2
stderr:
grep: unrecognized option: Q
Usage: grep [-HhnlLoqvsrRiwFE] [-m N] [-A|B|C N] { PATTERN | -e PATTERN... | -f FILE... } [FILE]...

Search for PATTERN in FILEs (or stdin)

	-n	Add 'line_no:' prefix
	-l	Show only names of files that match
	-c	Show only count of matching lines
	-q	Quiet. Return 0 if PATTERN is found, 1 otherwise
	-s	Suppress open and read errors
	-v	Select non-matching lines
	-i	Ignore case
	-w	Match whole words only
	-x	Match whole lines only
	-F	PATTERN is a literal (not regexp)
	-E	PATTERN is an extended regexp
	-e PTRN	Pattern to match
	-f FILE	Read pattern from file
status 2
```

### a long option, and -e and -f with nothing after them

```grep
(do (run (list "--nope" "a") "") (run (list "-e") "") (run (list "-f") ""))
```
---
```output
stderr:
grep: unrecognized option: nope
Usage: grep [-HhnlLoqvsrRiwFE] [-m N] [-A|B|C N] { PATTERN | -e PATTERN... | -f FILE... } [FILE]...

Search for PATTERN in FILEs (or stdin)

	-n	Add 'line_no:' prefix
	-l	Show only names of files that match
	-c	Show only count of matching lines
	-q	Quiet. Return 0 if PATTERN is found, 1 otherwise
	-s	Suppress open and read errors
	-v	Select non-matching lines
	-i	Ignore case
	-w	Match whole words only
	-x	Match whole lines only
	-F	PATTERN is a literal (not regexp)
	-E	PATTERN is an extended regexp
	-e PTRN	Pattern to match
	-f FILE	Read pattern from file
status 2
stderr:
grep: option requires an argument: e
Usage: grep [-HhnlLoqvsrRiwFE] [-m N] [-A|B|C N] { PATTERN | -e PATTERN... | -f FILE... } [FILE]...

Search for PATTERN in FILEs (or stdin)

	-n	Add 'line_no:' prefix
	-l	Show only names of files that match
	-c	Show only count of matching lines
	-q	Quiet. Return 0 if PATTERN is found, 1 otherwise
	-s	Suppress open and read errors
	-v	Select non-matching lines
	-i	Ignore case
	-w	Match whole words only
	-x	Match whole lines only
	-F	PATTERN is a literal (not regexp)
	-E	PATTERN is an extended regexp
	-e PTRN	Pattern to match
	-f FILE	Read pattern from file
status 2
stderr:
grep: option requires an argument: f
Usage: grep [-HhnlLoqvsrRiwFE] [-m N] [-A|B|C N] { PATTERN | -e PATTERN... | -f FILE... } [FILE]...

Search for PATTERN in FILEs (or stdin)

	-n	Add 'line_no:' prefix
	-l	Show only names of files that match
	-c	Show only count of matching lines
	-q	Quiet. Return 0 if PATTERN is found, 1 otherwise
	-s	Suppress open and read errors
	-v	Select non-matching lines
	-i	Ignore case
	-w	Match whole words only
	-x	Match whole lines only
	-F	PATTERN is a literal (not regexp)
	-E	PATTERN is an extended regexp
	-e PTRN	Pattern to match
	-f FILE	Read pattern from file
status 2
```

### no pattern at all is the usage text alone

```grep
(do (run () "") (run (list "-i") ""))
```
---
```output
stderr:
Usage: grep [-HhnlLoqvsrRiwFE] [-m N] [-A|B|C N] { PATTERN | -e PATTERN... | -f FILE... } [FILE]...

Search for PATTERN in FILEs (or stdin)

	-n	Add 'line_no:' prefix
	-l	Show only names of files that match
	-c	Show only count of matching lines
	-q	Quiet. Return 0 if PATTERN is found, 1 otherwise
	-s	Suppress open and read errors
	-v	Select non-matching lines
	-i	Ignore case
	-w	Match whole words only
	-x	Match whole lines only
	-F	PATTERN is a literal (not regexp)
	-E	PATTERN is an extended regexp
	-e PTRN	Pattern to match
	-f FILE	Read pattern from file
status 2
stderr:
Usage: grep [-HhnlLoqvsrRiwFE] [-m N] [-A|B|C N] { PATTERN | -e PATTERN... | -f FILE... } [FILE]...

Search for PATTERN in FILEs (or stdin)

	-n	Add 'line_no:' prefix
	-l	Show only names of files that match
	-c	Show only count of matching lines
	-q	Quiet. Return 0 if PATTERN is found, 1 otherwise
	-s	Suppress open and read errors
	-v	Select non-matching lines
	-i	Ignore case
	-w	Match whole words only
	-x	Match whole lines only
	-F	PATTERN is a literal (not regexp)
	-E	PATTERN is an extended regexp
	-e PTRN	Pattern to match
	-f FILE	Read pattern from file
status 2
```

## the patterns

### -e given twice, and -f, each line a pattern; a cluster of flags

```grep
(do (run (list "-e" "a" "-e" "c") "a\nb\nc\n") (run (list "-f" "/tmp/x-grep-cli.pats") "a\nb\nc\n") (run (list "-vn" "b") "a\nb\nc\n"))
```
---
```output
a
c
stderr:
status 0
b
stderr:
status 0
1:a
3:c
stderr:
status 0
```

### -- ends the options, so the next word is the pattern though it looks like one

```grep
(run (list "--" "-v") "a\n-v\n")
```
---
```output
-v
stderr:
status 0
```

### the cleanup

```grep
(do (file-unlink "/tmp/x-grep-cli.err") (file-unlink "/tmp/x-grep-cli.pats") (display "gone"))
```
---
    gone
