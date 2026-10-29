# @weight 1

The BRE translator: POSIX BRE text to the engine's ERE-like dialect.
Bare ( ) { } + ? | are BRE literals and gain escapes; backslashed
\( \) \{ \} \| \+ \? are the operators and lose theirs.  A [:named:]
class expands to its bytes inside the bracket.  Back-references refuse
loudly.

## the escape swap

### bare grouping characters become literals

```grep
(display (grep-xlate-bre "a(b){c}"))
```
---
    a\(b\)\{c\}

### backslashed operators become operators

```grep
(display (grep-xlate-bre "a\\(b\\)\\{2\\}"))
```
---
    a(b){2}

### bare + ? | are BRE literals

```grep
(display (grep-xlate-bre "a+b?c|d"))
```
---
    a\+b\?c\|d

### backslashed \| \+ \? are the operators

```grep
(display (grep-xlate-bre "a\\+b\\?c\\|d"))
```
---
    a+b?c|d

### a bare one stays literal beside its escaped twin

```grep
(do (display (grep-xlate-bre "a|b\\|b")) (newline) (display (grep-xlate-bre "a+\\+b")) (newline) (display (grep-xlate-bre "a?\\?b")))
```
---
```output
a\|b|b
a\++b
a\??b
```

### the operators apply to a group

```grep
(display (grep-xlate-bre "\\(a\\|b\\)\\+c"))
```
---
    (a|b)+c

### classes pass through

```grep
(display (grep-xlate-bre "[a-c]x[^y]"))
```
---
    [a-c]x[^y]

### a first-position ] is a member, spelled \] for the engine

```grep
(do (display (grep-xlate-bre "[]]")) (newline) (display (grep-xlate-bre "[^]]")) (newline) (display (grep-xlate-bre "[]a]")) (newline) (display (grep-xlate-bre "[^]a]")) (newline) (display (grep-xlate-bre "[]-a]")) (newline) (display (grep-xlate-bre "a]")))
```
---
```output
[\]]
[^\]]
[\]a]
[^\]a]
[\]^-a]
a]
```

### a \ in a bracket is a member, spelled \\ for the engine

```grep
(do (display (grep-xlate-bre "[\\]")) (newline) (display (grep-xlate-bre "[a\\]")) (newline) (display (grep-xlate-bre "[\\]]")) (newline) (display (grep-xlate-bre "[\\-a]")) (newline) (display (grep-xlate-bre "[Z-\\]")) (newline) (display (grep-xlate-bre "[ \\t]")))
```
---
```output
[\\]
[a\\]
[\\]]
[\\\]^-a]
[Z-\]
[ \\t]
```

## named classes

### a name expands to its bytes inside the bracket

```grep
(do (display (grep-xlate-bre "[[:digit:]]")) (newline) (display (grep-xlate-bre "[^[:alpha:]_]")) (newline) (display (grep-xlate-bre "[[:upper:][:xdigit:]]")) (newline) (display (grep-xlate-bre "[[:blank:]]")))
```
---
```output
[0-9]
[^a-zA-Z_]
[A-Z0-9A-Fa-f]
[ 	]
```

## the refusals

### back-references

```grep
(grep-run (list "a\\1") "x\n")
```
---
    Error: #<err:grep grep: back-references are not supported>

### a class name regcomp does not know, and a bracket left open

```grep
(do (display (guard (e (e msg)) (grep-run (list "[[:foo:]]") "a\n"))) (newline) (display (guard (e (e msg)) (grep-run (list "-E" "[[:]") "a:\n"))) (newline) (display (guard (e (e msg)) (grep-run (list "[[:digit:]") "a1\n"))))
```
---
```output
grep: bad regex '[[:foo:]]': Unknown character class name
grep: bad regex '[[:]': Unknown character class name
grep: bad regex '[[:digit:]': Missing ']'
```
