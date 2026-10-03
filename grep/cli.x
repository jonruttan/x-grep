; # x-grep -- POSIX grep on x-lang
;
; ## grep/cli.x -- the command line
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
;   x -l grep -- [-EFcilnqsvwx] [-e pat]... [-f patfile]... [pat] [file]...
;   x -l grep -- --help
;
; The `--` lets grep's own short options through x.sh's parsing (which
; would otherwise claim -e, -f, -F, -l, -q and -v for itself); without
; it, place options after the pattern.  The engine-flag stripping and
; the fd-3 stdin reclaim are x-awk's, unchanged.

(def %grep-cli-engine-flag?
  (fn (_ s)
    (if (string=? s "--quiet") #t
      (if (string=? s "--batch") #t
        (if (string=? s "--no-color") #t (string=? s "--verbose"))))))

(def grep-argv
  (fn (_ raw)
    (def ops
      (filter (fn (_ a) (not (%grep-cli-engine-flag? a)))
        (if (pair? raw) (rest raw) ())))
    (if (if (pair? ops) (string=? (first ops) "--") #f)
      (rest ops)
      ops)))

; stdin, read once from the caller's fd (waiting on fd 3 -- the
; platform's arrangement; see x-awk).  4096-byte chunks until the
; bundle's minimum x-lang tree carries the Str8 make fix.
(def %grep-stdin!
  (fn (_)
    (sys-dup2 3 0)
    (sys-close 3)
    (def slurp
      (fn (self acc)
        (let ((chunk (file-read-fd 0 4096)))
          (if (if (> (byte-len chunk) 0) #t #f)
            (self (pair chunk acc))
            (string-concat (reverse acc))))))
    (slurp ())))

; Run the command line and DO NOT RETURN.
(def grep-main
  (fn (_ raw-args)
    (def argv (grep-argv raw-args))
    ; read stdin only when something will consume it: a line that runs,
    ; with no file operands or a "-" among them
    (def plan (if (Opts help? %grep-options argv) () (grep-parse-cli argv)))
    (def files (if (null? plan) () (first (rest (rest plan)))))
    (def wants-stdin?
      (if (null? plan) #f
        (if (null? files) #t
        (let ((go (fn (self fs)
                    (if (null? fs) #f
                      (if (string=? (first fs) "-") #t (self (rest fs)))))))
          (go files)))))
    (sys-exit (grep-run argv (if wants-stdin? (%grep-stdin!) "")))))
