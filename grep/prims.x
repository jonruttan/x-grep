; # x-grep -- POSIX grep on x-lang
;
; ## grep/prims.x -- the platform layer, under the names grep is written
; against
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; A trimmed copy of x-awk's layer, and the same rules apply: public
; classes and catalog prims only, byte doors for anything per-character
; (Str8 class dispatch measured ~0.4ms PER CHARACTER in x-awk's pass),
; and no defs at depth in anything hot.

(import x/type/regex)
(import x/sys/file)
(import x/sys/opts)

(provide grep/prims
  char->integer integer->char byte-at byte-len
  string-length string-ref substring string-append string-concat
  string=? make-string list->string
  length reverse append map filter set-first!
  regex-compile regex-search regex-match
  file-read-all file-read-fd file-write file-exists?
  file-open-write file-close file-unlink
  sys-exit sys-dup2 sys-close)

(def char->integer (prim-ref (lit char) (lit ->int)))
(def integer->char (prim-ref (lit int) (lit ->char)))
(def byte-at (prim-ref (lit str) (lit byte-ref)))
(def byte-len (prim-ref (lit str) (lit byte-len)))

(def string-length (fn (_ s) (Str8 length s)))
(def string-ref (fn (_ s i) (Str8 ref i s)))
(def substring (fn (_ s a b) (Str8 sub a (- b a) s)))
(def string=? (fn (_ a b) (str=? a b)))
(def make-string (fn (_ n c) (Str8 make n c)))

(def %cvt (prim-ref (lit convert) (lit to)))
; The string type's handle, fetched by name through the platform's public
; door.
(def %grep-string-type (Type named STRING))
(def list->string (fn (_ l) (if (null? l) "" (%cvt l %grep-string-type))))

(def string-append (fn (_ . ss) (string-concat ss)))
(def string-concat
  (fn (self ss)
    (if (null? ss)
      ""
      (if (null? (rest ss)) (first ss) (Str8 append (first ss) (self (rest ss)))))))

(def length (fn (_ l) (List length l)))
(def reverse (fn (_ l) (%grep-rev l ())))
(def %grep-rev
  (fn (self l acc)
    (if (null? l) acc (self (rest l) (pair (first l) acc)))))
(def append (fn (_ a b) (List append a b)))
(def map (fn (_ f l) (List map f l)))
(def filter (fn (_ p l) (List filter p l)))
(def set-first! %set-first!)

(def regex-compile (fn (_ pattern) (Regex compile pattern)))
(def regex-search (fn (_ s rx) (Regex search s rx)))
(def regex-match (fn (_ s rx) (Regex match s rx)))

; File read/write are the raw syscall patterns -- see x-awk/awk/prims.x.
(def file-read-all (fn (_ path) (File read-all path)))
(def file-write
  (fn (_ fd s) (File write fd s (string-length s))))
; n writable bytes for a raw read to fill.  A string made with a NUL fill is
; not that: strings are C strings, so it is the empty string, a buffer of one
; byte, and the platform refuses to make it.
(def %str-make-raw (prim-ref (lit str) (lit make)))
(def file-read-fd
  (fn (_ fd n)
    (def buf (%str-make-raw n))
    (def r (File read fd buf n))
    (if (if (number? r) (> r 0) #f) (substring buf 0 r) "")))
(def file-exists? (fn (_ path) (File exists? path)))
(def file-open-write
  (fn (_ path) (File open path (list (lit wronly) (lit creat) (lit trunc)))))
(def file-close (fn (_ fd) (File close fd)))
(def file-unlink (fn (_ path) (File unlink path)))

(def sys-exit (fn (_ n) (Sys exit n)))
(def sys-dup2 (fn (_ a b) (Sys dup2 a b)))
(def sys-close (fn (_ fd) (Sys close fd)))
