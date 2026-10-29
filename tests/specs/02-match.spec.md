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

### BRE: \| alternates, bare | is literal

```grep
(do (display (grep-run (list "-o" "b\\|c") "abc\n")) (newline) (display (grep-run (list "a\\|b") "a|b\nab\n")) (newline) (display (grep-run (list "-o" "a|b\\|b") "a|b\nab\nb\n")) (newline) (display (grep-run (list "-o" "b\\|c") "b|c\n")))
```
---
```output
b
c
0
a|b
ab
0
a|b
b
b
0
b
c
0
```

### BRE: \+ repeats, bare + is literal

```grep
(do (display (grep-run (list "a\\+b") "ab\naab\nb\n")) (newline) (display (grep-run (list "-o" "a\\+b") "ab\naab\na+b\n")) (newline) (display (grep-run (list "-o" "a+\\+b") "a+b\naab\n")))
```
---
```output
ab
aab
0
ab
aab
0
a+b
0
```

### BRE: \? makes optional, bare ? is literal

```grep
(do (display (grep-run (list "a\\?b") "ab\nb\na?b\n")) (newline) (display (grep-run (list "-o" "a?\\?b") "ab\nb\na?b\n")) (newline) (display (grep-run (list "-x" "a\\?b") "ab\nb\n")))
```
---
```output
ab
b
a?b
0
ab
a?b
0
ab
b
0
```

### BRE: \+ and \| on a group

```grep
(do (display (grep-run (list "-o" "\\(ab\\)\\+") "abab\nab\n")) (newline) (display (grep-run (list "-o" "\\(a\\|b\\)c") "ac\nbc\ncc\n")))
```
---
```output
abab
ab
0
ac
bc
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

## named classes

### [:digit:], [:space:] and [:blank:] in BRE and ERE

```grep
(do (display (grep-run (list "[[:digit:]]") "a1\nb\n")) (newline) (display (grep-run (list "-E" "[[:digit:]]+") "a1\nb\n")) (newline) (display (grep-run (list "a[[:space:]]b") "a b\nab\n")) (newline) (display (grep-run (list "[[:space:]]") "a\tb\n")) (newline) (display (grep-run (list "a[[:blank:]]b") "a b\na\tb\na\nb\n")))
```
---
```output
a1
0
a1
0
a b
0
a	b
0
a b
a	b
0
```

### a negated class, and two names in one bracket

```grep
(do (display (grep-run (list "[^[:space:]]") "a\n \n\t\n")) (newline) (display (grep-run (list "[[:alpha:][:digit:]]") "a\n1\n-\n")))
```
---
```output
a
0
a
1
0
```

### a ] first in the bracket is a member, in BRE and ERE

```grep
(do (display (grep-run (list "[]]") "a]b\nAxB\nqaq\nzzz\n")) (newline) (display (grep-run (list "-E" "[]]") "a]b\nAxB\nqaq\nzzz\n")) (newline) (display (grep-run (list "[]a]") "a]b\nAxB\nqaq\nzzz\n")) (newline) (display (grep-run (list "-E" "[]a]") "a]b\nAxB\nqaq\nzzz\n")) (newline) (display (grep-run (list "\\[[0-9][^]]*\\]") "## [0.39.0] - x\n## [0.39.0 - x\n")))
```
---
```output
a]b
0
a]b
0
a]b
qaq
0
a]b
qaq
0
## [0.39.0] - x
0
```

### a ] first after the ^ is excluded, in BRE and ERE

```grep
(do (display (grep-run (list "[^]]") "a]b\nAxB\nqaq\nzzz\n]\n")) (newline) (display (grep-run (list "-E" "[^]]") "a]b\nAxB\nqaq\nzzz\n]\n")) (newline) (display (grep-run (list "[^]a]") "a]b\nAxB\nqaq\nzzz\n]a\n")) (newline) (display (grep-run (list "-E" "[^]a]") "a]b\nAxB\nqaq\nzzz\n]a\n")))
```
---
```output
a]b
AxB
qaq
zzz
0
a]b
AxB
qaq
zzz
0
a]b
AxB
qaq
zzz
0
a]b
AxB
qaq
zzz
0
```

### -i leaves the ] alone and folds the letter beside it

```grep
(do (display (grep-run (list "-i" "[]]") "a]b\nAxB\nqaq\nzzz\n")) (newline) (display (grep-run (list "-iE" "[]a]") "a]b\nAxB\nqaq\nzzz\n")) (newline) (display (grep-run (list "-i" "[^]a]") "a]b\nAxB\nqaq\nzzz\n]a\n")) (newline) (display (grep-run (list "-iE" "[^]]") "a]b\nAxB\nqaq\nzzz\n]\n")))
```
---
```output
a]b
0
a]b
AxB
qaq
0
a]b
AxB
qaq
zzz
0
a]b
AxB
qaq
zzz
0
```

### [:upper:] and [:lower:], and -i folding both

```grep
(do (display (grep-run (list "[[:upper:]]") "a\nA\n1\n")) (newline) (display (grep-run (list "[[:lower:]]") "a\nA\n1\n")) (newline) (display (grep-run (list "-i" "[[:upper:]]") "a\nA\n1\n")) (newline) (display (grep-run (list "-i" "[[:lower:]]") "a\nA\n1\n")))
```
---
```output
A
0
a
0
a
A
0
a
A
0
```

### [:punct:], [:xdigit:], [:alnum:] with a literal beside it, and a - after a name

```grep
(do (display (grep-run (list "[[:punct:]]") "a\n!\n]\n-\n\\\n^\n \n")) (newline) (display (grep-run (list "[[:xdigit:]]") "f\ng\n9\nG\n")) (newline) (display (grep-run (list "[[:alnum:]_]") "a\n_\n-\n")) (newline) (display (grep-run (list "[[:alpha:]-]") "a-z\n")))
```
---
```output
!
]
-
\
^
0
f
9
0
a
_
0
a-z
0
```

### -o with a class

```grep
(do (display (grep-run (list "-o" "[[:alpha:]]*") "ab12cd\n")) (newline) (display (grep-run (list "-oE" "[[:digit:]]+") "ab12cd\n")) (newline) (display (grep-run (list "-o" "[[:upper:]]") "aXb\n")) (newline) (display (grep-run (list "-oi" "[[:lower:]]") "aXb\n")))
```
---
```output
ab
cd
0
12
0
X
0
a
X
b
0
```

### -F sees no class; a name outside a bracket is itself

```grep
(do (display (grep-run (list "-F" "[[:alpha:]]") "a\n[[:alpha:]]\n")) (newline) (display (grep-run (list "a[[:alpha:]]b") "ab\n")))
```
---
```output
[[:alpha:]]
0
1
```
