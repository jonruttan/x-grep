# @weight 2

Context lines and the match limit, as busybox 1.36.1's grep prints them:
-A, -B and -C around a selected line, each context line's prefix joined
with - rather than :, a -- between groups that are not adjacent, and -m
stopping a file after its Nth selected line, once the trailing context is
out.  The separator's state spans files -- a quirk of the oracle, kept.
Every expectation from a busybox run; a case's last output line is the
exit status, and a case with a complaint shows `stderr:` and what grep
wrote there.

## the fixture

### a run of grep with its stderr, and two files

```grep
(def %ctx-err "/tmp/x-grep-ctx.err")
(def run (fn (_ argv input) (do (sys-dup2 2 8) (def e (file-open-write %ctx-err)) (sys-dup2 e 2) (def st (grep-run argv input)) (sys-dup2 8 2) (file-close e) (display "stderr:\n") (display (file-read-all %ctx-err)) (display "status ") (display st) (newline))))
(def %ctx-text "a\nb\nc\nd\nb\ne\n")
(file-close (let ((fd (file-open-write "/tmp/x-grep-ctx-1.txt"))) (do (file-write fd "x\n") fd)))
(file-close (let ((fd (file-open-write "/tmp/x-grep-ctx-2.txt"))) (do (file-write fd "y\nx\n") fd)))
(display "made")
```
---
    made

## -A, -B, -C

### trailing context, with a separator between groups

```grep
(display (grep-run (list "-A1" "b") %ctx-text))
```
---
```output
b
c
--
b
e
0
```

### leading context

```grep
(display (grep-run (list "-B1" "b") %ctx-text))
```
---
```output
a
b
--
d
b
0
```

### both, with adjacent groups and no separator

```grep
(display (grep-run (list "-C1" "b") %ctx-text))
```
---
```output
a
b
c
d
b
e
0
```

### -n joins a context line's number with -

```grep
(do (display (grep-run (list "-n" "-A1" "b") %ctx-text)) (newline) (display (grep-run (list "-nB2" "b") %ctx-text)))
```
---
```output
2:b
3-c
--
5:b
6-e
0
1-a
2:b
3-c
4-d
5:b
0
```

### leading context stops at the last line printed

```grep
(do (display (grep-run (list "-nB2" "b") "a\nb\nc\nd\ne\nb\n")) (newline) (display (grep-run (list "-nC1" "b") "q\nb\nq\nq\nq\nb\n")))
```
---
```output
1-a
2:b
--
4-d
5-e
6:b
0
1-q
2:b
3-q
--
5-q
6:b
0
```

### adjacent matches share no separator; context past the end is what there is

```grep
(do (display (grep-run (list "-A1" "b") "b\nb\nc\n")) (newline) (display (grep-run (list "-nA" "5" "a") "a\nb\nc\n")) (newline) (display (grep-run (list "-B9" "c") "a\nb\nc\nb\n")))
```
---
```output
b
b
c
0
1:a
2-b
3-c
0
a
b
c
0
```

### -C sets what -A and -B did not say after it

```grep
(do (display (grep-run (list "-C2" "-A0" "b") %ctx-text)) (newline) (display (grep-run (list "-A0" "-C1" "b") %ctx-text)) (newline) (display (grep-run (list "-A" "1" "-B" "1" "-C" "1" "x") "x\n")))
```
---
```output
a
b
c
d
b
0
a
b
c
d
b
e
0
x
0
```

### a zero is no context

```grep
(do (display (grep-run (list "-A" "0" "-B" "0" "x") "x\n")) (newline) (display (grep-run (list "-C" "0" "a") "a\nb\n")))
```
---
```output
x
0
a
0
```

### -c, -q and -l print no context

```grep
(do (display (grep-run (list "-c" "-A1" "b") %ctx-text)) (newline) (display (grep-run (list "-q" "-A1" "x") "x\n")))
```
---
```output
2
0
0
```

### -v's context is the matching lines; several patterns share one context

```grep
(do (display (grep-run (list "-A1" "-v" "b") %ctx-text)) (newline) (display (grep-run (list "-A1" "-e" "a" "-e" "c") "a\nb\nc\n")))
```
---
```output
a
b
c
d
b
e
0
a
b
c
0
```

### -o -v leaves a context line's prefix alone and unterminated

```grep
(do (display (grep-run (list "-ov" "-A1" "x") "x\ny\nx\n")) (newline) (display (grep-run (list "-nov" "-A1" "x") "x\ny\nx\n")))
```
---
```output
0
3-0
```

### the separator's state spans files

```grep
(do (display (grep-run (list "-A1" "x" "/tmp/x-grep-ctx-1.txt" "/tmp/x-grep-ctx-2.txt") "")) (newline) (display (grep-run (list "-nC1" "x" "/tmp/x-grep-ctx-1.txt" "/tmp/x-grep-ctx-2.txt") "")))
```
---
```output
/tmp/x-grep-ctx-1.txt:x
/tmp/x-grep-ctx-2.txt:x
0
/tmp/x-grep-ctx-1.txt:1:x
--
/tmp/x-grep-ctx-2.txt-1-y
/tmp/x-grep-ctx-2.txt:2:x
0
```

## -m, the match limit

### N selected lines a file, and 0 reads one line and still answers 0

```grep
(do (display (grep-run (list "-m1" "x") "x\nx\n")) (newline) (display (grep-run (list "-m0" "x") "x\nx\n")) (newline) (display (grep-run (list "-m2" "-n" "x") "x\nx\nx\n")))
```
---
```output
x
0
0
1:x
2:x
0
```

### the trailing context comes out first

```grep
(display (grep-run (list "-m1" "-A1" "x") "x\ny\nx\n"))
```
---
```output
x
y
0
```

### -c counts to the limit; -v's selected lines count

```grep
(do (display (grep-run (list "-c" "-m2" "x") "x\nx\nx\n")) (newline) (display (grep-run (list "-m1" "-v" "x") "x\ny\ny\n")) (newline) (display (grep-run (list "-m" "1" "-c" "-v" "b") "a\na\n")))
```
---
```output
2
0
y
0
1
0
```

### -l, -L and a second file each see the limit

```grep
(do (display (grep-run (list "-m" "1" "-l" "x") "x\nx\n")) (newline) (display (grep-run (list "-L" "-m1" "x") "x\nx\n")) (newline) (display (grep-run (list "-m1" "-c" "x" "/tmp/x-grep-ctx-1.txt" "/tmp/x-grep-ctx-2.txt") "")))
```
---
```output
(standard input)
0
1
/tmp/x-grep-ctx-1.txt:1
/tmp/x-grep-ctx-2.txt:1
0
```

### a count is digits only; the last of a repeated one counts

```grep
(do (run (list "-A" "x" "a") "x\n") (run (list "-m" "-1" "x") "x\n") (run (list "-A1x" "x") "x\n") (run (list "-m" "1x" "x") "x\n") (run (list "-m" "+1" "a") "a\n") (run (list "-m" "01" "a") "a\n") (run (list "-A" "1" "-A" "2" "x") "x\n"))
```
---
```output
stderr:
grep: invalid number 'x'
status 2
stderr:
grep: invalid number '-1'
status 2
stderr:
grep: invalid number '1x'
status 2
stderr:
grep: invalid number '1x'
status 2
stderr:
grep: invalid number '+1'
status 2
a
stderr:
status 0
x
stderr:
status 0
```

### the cleanup

```grep
(do (file-unlink %ctx-err) (file-unlink "/tmp/x-grep-ctx-1.txt") (file-unlink "/tmp/x-grep-ctx-2.txt") (display "gone"))
```
---
    gone
