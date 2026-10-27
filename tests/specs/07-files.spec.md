# @weight 2

The operands as busybox 1.36.1's grep reads them: -r and -R walk a
directory operand, in the order the kernel lists it, a directory without
them reads as nothing, and a file that will not open is a complaint and 2
-- unless -q found something first.  The fixture is a tree under
/tmp/x-grep-r; every case names one match a directory, so the kernel's
order never shows.  Every expectation from a busybox run on the same
tree; a case's last output line is the exit status, and a case with a
complaint shows `stderr:` and what grep wrote there.

## the fixture

### a tree of files, directories and links, and a run with its stderr

```grep
(def %r "/tmp/x-grep-r")
(def %r-err "/tmp/x-grep-r.err")
(def put (fn (_ path text) (file-close (let ((fd (file-open-write path))) (do (file-write fd text) fd)))))
(File mkdir %r)
(File mkdir (Str8 append %r "/d"))
(File mkdir (Str8 append %r "/d/sub"))
(File mkdir (Str8 append %r "/other"))
(File mkdir (Str8 append %r "/e"))
(put (Str8 append %r "/one.txt") "x\n")
(put (Str8 append %r "/two.txt") "y\nx\n")
(put (Str8 append %r "/three.txt") "ax\n")
(put (Str8 append %r "/d/a.txt") "ax\n")
(put (Str8 append %r "/d/sub/b.txt") "bx\nz\n")
(put (Str8 append %r "/other/c.txt") "cx\n")
(File symlink "../other" (Str8 append %r "/d/link"))
(File symlink "../other/c.txt" (Str8 append %r "/d/flink"))
(File symlink "../other" (Str8 append %r "/e/link"))
(def run (fn (_ argv input) (do (sys-dup2 2 8) (def e (file-open-write %r-err)) (sys-dup2 e 2) (def st (grep-run argv input)) (sys-dup2 8 2) (file-close e) (display "stderr:\n") (display (file-read-all %r-err)) (display "status ") (display st) (newline))))
(display "made")
```
---
    made

## -r and -R

### a directory operand is walked, subdirectories too, and the prefix is on

```grep
(do (display (grep-run (list "-r" "ax" "/tmp/x-grep-r/d") "")) (newline) (display (grep-run (list "-r" "bx" "/tmp/x-grep-r/d") "")))
```
---
```output
/tmp/x-grep-r/d/a.txt:ax
0
/tmp/x-grep-r/d/sub/b.txt:bx
0
```

### -r reads a link to a file and passes a link to a directory; -R walks it

```grep
(do (display (grep-run (list "-r" "cx" "/tmp/x-grep-r/d") "")) (newline) (display (grep-run (list "-r" "cx" "/tmp/x-grep-r/e") "")) (newline) (display (grep-run (list "-R" "cx" "/tmp/x-grep-r/e") "")))
```
---
```output
/tmp/x-grep-r/d/flink:cx
0
1
/tmp/x-grep-r/e/link/c.txt:cx
0
```

### a link named as the operand is followed either way

```grep
(display (grep-run (list "-r" "cx" "/tmp/x-grep-r/e/link") ""))
```
---
```output
/tmp/x-grep-r/e/link/c.txt:cx
0
```

### a trailing slash adds no second one; -n, -h, -l, -c, -o and -L

```grep
(do (display (grep-run (list "-r" "ax" "/tmp/x-grep-r/d/") "")) (newline) (display (grep-run (list "-rn" "bx" "/tmp/x-grep-r/d") "")) (newline) (display (grep-run (list "-rh" "ax" "/tmp/x-grep-r/d") "")) (newline) (display (grep-run (list "-rl" "ax" "/tmp/x-grep-r/d") "")) (newline) (display (grep-run (list "-rc" "ax" "/tmp/x-grep-r/d/sub") "")) (newline) (display (grep-run (list "-ro" "x" "/tmp/x-grep-r/d/sub") "")) (newline) (display (grep-run (list "-rL" "q" "/tmp/x-grep-r/d/sub") "")))
```
---
```output
/tmp/x-grep-r/d/a.txt:ax
0
/tmp/x-grep-r/d/sub/b.txt:1:bx
0
ax
0
/tmp/x-grep-r/d/a.txt
0
/tmp/x-grep-r/d/sub/b.txt:0
1
/tmp/x-grep-r/d/sub/b.txt:x
0
/tmp/x-grep-r/d/sub/b.txt
0
```

### a directory turns the prefix on for the operands after it

```grep
(display (grep-run (list "-r" "ax" "/tmp/x-grep-r/d" "/tmp/x-grep-r/three.txt") ""))
```
---
```output
/tmp/x-grep-r/d/a.txt:ax
/tmp/x-grep-r/three.txt:ax
0
```

### -q ends the walk; a file operand and standard input are as without -r

```grep
(do (display (grep-run (list "-rq" "ax" "/tmp/x-grep-r/d") "")) (newline) (display (grep-run (list "-r" "ax" "/tmp/x-grep-r/three.txt") "")) (newline) (display (grep-run (list "-r" "ax") "ax\n")))
```
---
```output
0
ax
0
ax
0
```

## directories and files that will not open

### a directory without -r reads as nothing

```grep
(do (display (grep-run (list "x" "/tmp/x-grep-r/d") "")) (newline) (display (grep-run (list "-c" "x" "/tmp/x-grep-r/d") "")) (newline) (display (grep-run (list "-c" "x" "/tmp/x-grep-r/d" "/tmp/x-grep-r/one.txt") "")))
```
---
```output
1
0
1
/tmp/x-grep-r/d:0
/tmp/x-grep-r/one.txt:1
0
```

### a missing file is a complaint and 2, after the others are read; -s keeps the 2

```grep
(do (run (list "x" "/tmp/x-grep-r/nope" "/tmp/x-grep-r/one.txt") "") (run (list "-s" "x" "/tmp/x-grep-r/nope" "/tmp/x-grep-r/one.txt") "") (run (list "-r" "x" "/tmp/x-grep-r/nope") ""))
```
---
```output
/tmp/x-grep-r/one.txt:x
stderr:
grep: /tmp/x-grep-r/nope: No such file or directory
status 2
/tmp/x-grep-r/one.txt:x
stderr:
status 2
stderr:
grep: /tmp/x-grep-r/nope: No such file or directory
status 2
```

### -q's hit answers 0 whatever would not open

```grep
(run (list "-q" "x" "/tmp/x-grep-r/nope" "/tmp/x-grep-r/one.txt") "")
```
---
```output
stderr:
grep: /tmp/x-grep-r/nope: No such file or directory
status 0
```

### the cleanup

```grep
(do (file-unlink %r-err) (file-unlink (Str8 append %r "/e/link")) (file-unlink (Str8 append %r "/d/flink")) (file-unlink (Str8 append %r "/d/link")) (file-unlink (Str8 append %r "/other/c.txt")) (file-unlink (Str8 append %r "/d/sub/b.txt")) (file-unlink (Str8 append %r "/d/a.txt")) (file-unlink (Str8 append %r "/three.txt")) (file-unlink (Str8 append %r "/two.txt")) (file-unlink (Str8 append %r "/one.txt")) (File rmdir (Str8 append %r "/e")) (File rmdir (Str8 append %r "/other")) (File rmdir (Str8 append %r "/d/sub")) (File rmdir (Str8 append %r "/d")) (File rmdir %r) (display "gone"))
```
---
    gone
