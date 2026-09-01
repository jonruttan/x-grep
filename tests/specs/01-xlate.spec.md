# @weight 1

The BRE translator: POSIX BRE text to the engine's ERE-shaped dialect.
Bare ( ) { } + ? | are BRE literals and gain escapes; backslashed
\( \) \{ \} are the operators and lose theirs.  Back-references and
[:named:] classes refuse loudly.

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

### ERE-only operators are BRE literals

```grep
(display (grep-xlate-bre "a+b?c|d"))
```
---
    a\+b\?c\|d

### classes pass through

```grep
(display (grep-xlate-bre "[a-c]x[^y]"))
```
---
    [a-c]x[^y]

## the refusals

### back-references

```grep
(grep-run (list "a\\1") "x\n")
```
---
    Error: #<err:grep grep: back-references are not supported>

### named classes

```grep
(grep-run (list "[[:digit:]]") "x\n")
```
---
    Error: #<err:grep grep: [:named:] classes are not supported yet>
