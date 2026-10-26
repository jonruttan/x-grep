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
; it, place options after the pattern.  The fd-3 stdin reclaim is
; x-awk's, unchanged.  The operands are (Sys args 'program) past the
; engine's path, which run.x hands grep-main.

(module grep/cli)
(import grep/prims byte-len string=? string-concat reverse file-read-fd
  sys-exit sys-dup2 sys-close)
(import grep/core grep-options grep-parse-cli grep-run)

; stdin, read once from the caller's fd (waiting on fd 3 -- the
; platform's arrangement; see x-awk).  4096-byte chunks until the
; bundle's minimum x-lang tree carries the Str8 make fix.
(def grep-stdin!
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
  (fn (_ argv)
    ; read stdin only when something will consume it: a line that runs,
    ; with no file operands or a "-" among them
    (def plan (if (Opts help? grep-options argv) () (grep-parse-cli argv)))
    (def files (if (null? plan) () (first (rest (rest plan)))))
    (def wants-stdin?
      (if (null? plan) #f
        (if (null? files) #t
        (let ((go (fn (self fs)
                    (if (null? fs) #f
                      (if (string=? (first fs) "-") #t (self (rest fs)))))))
          (go files)))))
    (sys-exit (grep-run argv (if wants-stdin? (grep-stdin!) "")))))

(provide grep/cli grep-main grep-stdin!)
