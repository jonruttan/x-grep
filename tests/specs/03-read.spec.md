# @weight 1

file-read-fd FD N: up to N bytes from a descriptor, as a string.  It is how
grep reads its standard input, and sed reads through it too.

## a descriptor's bytes

### a read answers what the file holds

```grep
(def %read-path "/tmp/x-grep-read-spec")
(def %read-out (file-open-write %read-path))
(file-write %read-out "aa\nbb\nab\n")
(file-close %read-out)
(def %read-in (File open %read-path (lit rdonly)))
(def %read-got (file-read-fd %read-in 4096))
(file-close %read-in)
(file-unlink %read-path)
(display %read-got)
(display (string-length %read-got))
```
---
```output
aa
bb
ab
9
```

### a read of fewer bytes than the file holds answers that many

```grep
(def %read-path "/tmp/x-grep-read-spec")
(def %read-out (file-open-write %read-path))
(file-write %read-out "aa\nbb\nab\n")
(file-close %read-out)
(def %read-in (File open %read-path (lit rdonly)))
(def %read-got (file-read-fd %read-in 4))
(file-close %read-in)
(file-unlink %read-path)
(display (string-length %read-got))
```
---
```output
4
```
