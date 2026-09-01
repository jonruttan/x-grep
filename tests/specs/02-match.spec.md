# @weight 2

grep-run ARGV INPUT: the selected lines to stdout, the status as the
value -- so a case's last output line is the exit status.  Every
expectation from a real (POSIX) grep run on the same input.

## selection

### the basic case

```grep
(display (grep-run (list "a") "aa\nbb\nab\n"))
```
---
```output
aa
ab
0
```

### -v inverts

```grep
(display (grep-run (list "-v" "a") "aa\nbb\nab\n"))
```
---
```output
bb
0
```

### -n numbers from one

```grep
(display (grep-run (list "-n" "a") "aa\nbb\nab\n"))
```
---
```output
1:aa
3:ab
0
```

### -c counts

```grep
(display (grep-run (list "-c" "a") "aa\nbb\nab\n"))
```
---
```output
2
0
```

### -x wants the whole line

```grep
(display (grep-run (list "-x" "a") "a\naa\n"))
```
---
```output
a
0
```

### -w wants word boundaries

```grep
(display (grep-run (list "-w" "cat") "cat x\nconcat y\n"))
```
---
```output
cat x
0
```

### bundled short flags

```grep
(display (grep-run (list "-in" "A") "xa\nAb\n"))
```
---
```output
1:xa
2:Ab
0
```

## case folding

### -i folds literals

```grep
(display (grep-run (list "-i" "A") "aa\nBB\nab\n"))
```
---
```output
aa
ab
0
```

### -i folds class ranges

```grep
(display (grep-run (list "-i" "[a-c]x") "BX\ndx\n"))
```
---
```output
BX
0
```

## the three dialects

### BRE: bare parens are literal

```grep
(display (grep-run (list "a(b)") "a(b)\nab\n"))
```
---
```output
a(b)
0
```

### BRE: backslashed parens group, braces count

```grep
(display (grep-run (list "a\\(b\\)") "a(b)\nab\n"))
```
---
```output
ab
0
```

### BRE: the interval

```grep
(display (grep-run (list "a\\{2\\}") "aab\nab\n"))
```
---
```output
aab
0
```

### -E: ERE operators live

```grep
(display (grep-run (list "-E" "a+b") "ab\naab\ncb\n"))
```
---
```output
ab
aab
0
```

### -E: alternation

```grep
(display (grep-run (list "-E" "(a|c)b") "ab\n"))
```
---
```output
ab
0
```

### -F: fixed strings, no magic

```grep
(display (grep-run (list "-F" "a.b") "a.b\naxb\n"))
```
---
```output
a.b
0
```

## patterns by option

### -e collects several

```grep
(display (grep-run (list "-e" "aa" "-e" "bb") "aa\nbb\ncc\n"))
```
---
```output
aa
bb
0
```

## the status

### no match is 1

```grep
(display (grep-run (list "zz") "aa\n"))
```
---
    1

### -q is quiet either way

```grep
(display (grep-run (list "-q" "a") "aa\n"))
```
---
    0

## files

### fixture

```grep
(do (def fd (file-open-write "/tmp/x-grep-spec-1.txt")) (file-write fd "x\n") (file-close fd) (def fd2 (file-open-write "/tmp/x-grep-spec-2.txt")) (file-write fd2 "y\nx\n") (file-close fd2) (display "made"))
```
---
    made

### two files turn the prefix on

```grep
(display (grep-run (list "x" "/tmp/x-grep-spec-1.txt" "/tmp/x-grep-spec-2.txt") ""))
```
---
```output
/tmp/x-grep-spec-1.txt:x
/tmp/x-grep-spec-2.txt:x
0
```

### -l names the files

```grep
(display (grep-run (list "-l" "x" "/tmp/x-grep-spec-1.txt" "/tmp/x-grep-spec-2.txt") ""))
```
---
```output
/tmp/x-grep-spec-1.txt
/tmp/x-grep-spec-2.txt
0
```

### a missing file is status 2, -s or not

```grep
(display (grep-run (list "-s" "x" "/tmp/x-grep-no-such-file") ""))
```
---
    2

### cleanup

```grep
(do (file-unlink "/tmp/x-grep-spec-1.txt") (file-unlink "/tmp/x-grep-spec-2.txt") (display "clean"))
```
---
    clean
