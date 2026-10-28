# @weight 2

What a selected line prints, past the line itself: -o's matching parts,
-w's loop around a match, the -h/-H name prefix and -L's names.  Every
expectation from a real grep on the same input -- busybox 1.36.1, and
where busybox stands alone, BSD grep, whose answer GNU grep shares.  A
case's last output line is the exit status.

## -o, the matching part

### every match on its own line

```grep
(display (grep-run (list "-o" "a") "aaa\nbab\n"))
```
---
```output
a
a
a
a
0
```

### ERE alternation, each match in turn

```grep
(display (grep-run (list "-oE" "a|b") "abab\n"))
```
---
```output
a
b
a
b
0
```

### an empty match prints nothing, and the line still counts

```grep
(display (grep-run (list "-o" "") "test\n"))
```
---
    0

### -n numbers each part with its line

```grep
(display (grep-run (list "-on" "a") "aaa\nbab\n"))
```
---
```output
1:a
1:a
1:a
2:a
0
```

### -c counts lines, not parts

```grep
(display (grep-run (list "-oc" "a") "aaa\nbab\n"))
```
---
```output
2
0
```

### -v selects nothing to show

```grep
(display (grep-run (list "-ov" "a") "aaa\nbab\n"))
```
---
    1

### -F prints each occurrence as it stands in the line

```grep
(do (display (grep-run (list "-oF" "a.b") "xa.bya.b\n")) (newline) (display (grep-run (list "-oF" "-i" "A.B") "xa.bya.b\n")))
```
---
```output
a.b
a.b
0
a.b
a.b
0
```

### -i prints the text as it was

```grep
(display (grep-run (list "-oi" "A") "aAa\n"))
```
---
```output
a
A
a
0
```

### -x prints the whole line

```grep
(display (grep-run (list "-ox" "a") "a\n"))
```
---
```output
a
0
```

### ^ matches only at the start, so one part

```grep
(display (grep-run (list "-o" "^a") "aaa\n"))
```
---
```output
a
0
```

### an empty match is stepped over

```grep
(display (grep-run (list "-o" "b*") "abb\n"))
```
---
```output
bb
0
```

### the name prefix, and a part that ends in a space

```grep
(do (display (grep-run (list "-oH" "x") "x\n")) (newline) (display (grep-run (list "-oE" "[a-z]+ ?") "ab cd\n")))
```
---
```output
(standard input):x
0
ab 
cd
0
```

### -w admits only the whole words, each of them (GNU; BSD stops at the first)

```grep
(display (grep-run (list "-ow" "cat") "cat concat cat\n"))
```
---
```output
cat
cat
0
```

### the earliest match of any pattern comes first, the longest at a tie

```grep
(do (display (grep-run (list "-o" "-e" "a" "-e" "b") "ab\n")) (newline) (display (grep-run (list "-o" "-e" "b" "-e" "a") "ab\n")) (newline) (display (grep-run (list "-o" "-e" "a" "-e" "ab") "ab\n")))
```
---
```output
a
b
0
a
b
0
ab
0
```

### -m stops the lines, not the parts

```grep
(display (grep-run (list "-m1" "-o" "x") "x\nx\n"))
```
---
```output
x
0
```

## -w, the loop around a match

### a match against a word byte is retried from its end

```grep
(do (display (grep-run (list "-w" "cat") "concat cat\n")) (newline) (display (grep-run (list "-w" "cat") "concat\n")))
```
---
```output
concat cat
0
1
```

### an empty match that does not move is given up

```grep
(do (display (grep-run (list "-w" "^") "foo\n")) (newline) (display (grep-run (list "^") "foo\n")))
```
---
```output
1
foo
0
```

### -w around an alternation

```grep
(do (display (grep-run (list "-owE" "a|b") "a b\n")) (newline) (display (grep-run (list "-owE" "a|b") "ab\n")))
```
---
```output
a
b
0
1
```

### -F -w steps one byte on

```grep
(do (display (grep-run (list "-wF" "x") "xx\n")) (newline) (display (grep-run (list "-wF" "x") "x x\n")) (newline) (display (grep-run (list "-wF" "x") "x_ x\n")))
```
---
```output
1
x x
0
x_ x
0
```

## -h and -H, the name prefix

### -H names standard input

```grep
(do (display (grep-run (list "-H" "x") "x\n")) (newline) (display (grep-run (list "-Hc" "x") "x\n")) (newline) (display (grep-run (list "-Hn" "x") "x\n")) (newline) (display (grep-run (list "-Hl" "x") "x\n")) (newline) (display (grep-run (list "-hc" "x") "x\n")))
```
---
```output
(standard input):x
0
(standard input):1
0
(standard input):1:x
0
(standard input)
0
1
0
```

### fixture

```grep
(do (def fd (file-open-write "/tmp/x-grep-spec-5a.txt")) (file-write fd "x\n") (file-close fd) (def fd2 (file-open-write "/tmp/x-grep-spec-5b.txt")) (file-write fd2 "y\nx\n") (file-close fd2) (display "made"))
```
---
    made

### -h drops the prefix two files turn on; the later of -h and -H wins

```grep
(do (display (grep-run (list "-h" "x" "/tmp/x-grep-spec-5a.txt" "/tmp/x-grep-spec-5b.txt") "")) (newline) (display (grep-run (list "-Hh" "x" "/tmp/x-grep-spec-5a.txt" "/tmp/x-grep-spec-5b.txt") "")) (newline) (display (grep-run (list "-hH" "x" "/tmp/x-grep-spec-5a.txt" "/tmp/x-grep-spec-5b.txt") "")))
```
---
```output
x
x
0
x
x
0
/tmp/x-grep-spec-5a.txt:x
/tmp/x-grep-spec-5b.txt:x
0
```

### -H names a lone file; -c takes the prefix too

```grep
(do (display (grep-run (list "-H" "x" "/tmp/x-grep-spec-5a.txt") "")) (newline) (display (grep-run (list "-c" "x" "/tmp/x-grep-spec-5a.txt" "/tmp/x-grep-spec-5b.txt") "")) (newline) (display (grep-run (list "-hc" "x" "/tmp/x-grep-spec-5a.txt" "/tmp/x-grep-spec-5b.txt") "")))
```
---
```output
/tmp/x-grep-spec-5a.txt:x
0
/tmp/x-grep-spec-5a.txt:1
/tmp/x-grep-spec-5b.txt:1
0
1
1
0
```

### -o takes the prefix

```grep
(display (grep-run (list "-o" "x" "/tmp/x-grep-spec-5a.txt" "/tmp/x-grep-spec-5b.txt") ""))
```
---
```output
/tmp/x-grep-spec-5a.txt:x
/tmp/x-grep-spec-5b.txt:x
0
```

## -L, the files that do not match

### standard input, matched and not

```grep
(do (display (grep-run (list "-L" "x") "x\n")) (newline) (display (grep-run (list "-L" "z") "x\n")) (newline) (display (grep-run (list "-L" "x") "")))
```
---
```output
1
(standard input)
0
(standard input)
0
```

### a named file is a match for the status

```grep
(do (display (grep-run (list "-L" "x" "/tmp/x-grep-spec-5a.txt" "/tmp/x-grep-spec-5b.txt") "")) (newline) (display (grep-run (list "-L" "z" "/tmp/x-grep-spec-5a.txt") "")) (newline) (display (grep-run (list "-L" "y" "/tmp/x-grep-spec-5a.txt" "/tmp/x-grep-spec-5b.txt") "")))
```
---
```output
1
/tmp/x-grep-spec-5a.txt
0
/tmp/x-grep-spec-5a.txt
0
```

### -L -c prints the count, then the name

```grep
(display (grep-run (list "-Lc" "y" "/tmp/x-grep-spec-5a.txt" "/tmp/x-grep-spec-5b.txt") ""))
```
---
```output
/tmp/x-grep-spec-5a.txt:0
/tmp/x-grep-spec-5a.txt
0
```

### -l before -L, -q before both

```grep
(do (display (grep-run (list "-lL" "a") "a\n")) (newline) (display (grep-run (list "-Lq" "a") "a\n")))
```
---
```output
(standard input)
0
0
```

### cleanup

```grep
(do (file-unlink "/tmp/x-grep-spec-5a.txt") (file-unlink "/tmp/x-grep-spec-5b.txt") (display "clean"))
```
---
    clean
