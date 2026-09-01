; # x-grep -- POSIX grep on x-lang
;
; ## grep/core.x -- options, the line loop, the status
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; grep-run ARGV INPUT -> status (0 match, 1 none, 2 trouble), output on
; stdout, complaints on fd 2.  INPUT stands for stdin -- the pure form
; the specs drive; the CLI passes a thunk-read of the real stdin.  File
; operands read through File; "-" is stdin; more than one file operand
; turns the name: prefix on, POSIX's rule.

; --- Option parsing (pure) ---------------------------------------------------
; Answers ((flags) (patterns) (files)); flags is a symbol list.  -e and
; -f collect patterns (joined or split spellings); bundled short flags
; (-inv) unbundle; -- ends options; the first operand is the pattern
; only when -e/-f gave none.

(def %grep-flag-syms
  (list (pair 69 (lit ere)) (pair 70 (lit fixed))          ; E F
    (pair 99 (lit count)) (pair 105 (lit ci))              ; c i
    (pair 108 (lit names)) (pair 110 (lit lineno))         ; l n
    (pair 113 (lit quiet)) (pair 115 (lit silent))         ; q s
    (pair 118 (lit invert)) (pair 119 (lit word))          ; v w
    (pair 120 (lit xline))))                               ; x

(def %grep-flag-sym
  (fn (_ b)
    (def go
      (fn (self es)
        (if (null? es) ()
          (if (= (first (first es)) b)
            (rest (first es))
            (self (rest es))))))
    (go %grep-flag-syms)))

; one -X arg: value from the joined or the split spelling
(def %grep-optarg
  (fn (_ op ops)
    (if (> (byte-len op) 2)
      (pair (substring op 2 (byte-len op)) (rest ops))
      (if (null? (rest ops))
        (Err raise (lit grep)
          (string-append "grep: option needs an argument: " op) ())
        (pair (first (rest ops)) (rest (rest ops)))))))

(def grep-parse-cli
  (fn (_ operands)
    (def unbundle
      (fn (self op i flags)
        (if (>= i (byte-len op)) flags
          (let ((sym (%grep-flag-sym (byte-at op i))))
            (if (null? sym)
              (Err raise (lit grep)
                (string-append "grep: unknown option: " op) ())
              (self op (+ i 1) (pair sym flags)))))))
    (def go
      (fn (self ops flags pats saw-pat?)
        (if (null? ops)
          (list flags (reverse pats) ())
          (let ((op (first ops)))
            (if (if (>= (byte-len op) 2) (= (byte-at op 0) 45) #f)  ; -X
              (let ((b1 (byte-at op 1)))
                (if (= b1 45)                                       ; --
                  ; options end; when nothing named a pattern yet, the
                  ; next operand is it
                  (let ((tail (rest ops)))
                    (if (if saw-pat? #t (not (null? pats)))
                      (list flags (reverse pats) tail)
                      (if (null? tail)
                        (Err raise (lit grep) "grep: no pattern" ())
                        (list flags (list (first tail)) (rest tail)))))
                  (if (= b1 101)                                    ; e
                    (let ((r (%grep-optarg op ops)))
                      (self (rest r) flags (pair (first r) pats) #t))
                    (if (= b1 102)                                  ; f
                      (let ((r (%grep-optarg op ops)))
                        (self (rest r) flags
                          (append (reverse (%grep-pat-lines (first r)))
                            pats)
                          #t))
                      (self (rest ops) (unbundle op 1 flags)
                        pats saw-pat?)))))
              ; first non-option: the pattern, unless -e/-f already spoke
              (if (if saw-pat? #t (not (null? pats)))
                (list flags (reverse pats) ops)
                (self (rest ops) flags (pair op pats) #t)))))))
    ; -- handling above is clumsy for the pattern-after--- case; keep
    ; the common shapes correct: [opts] [pat] [files], -- ends opts.
    (go operands () () #f)))

; a -f file: one pattern per line
(def %grep-pat-lines
  (fn (_ path)
    (if (file-exists? path)
      (%grep-lines (file-read-all path))
      (Err raise (lit grep)
        (string-append "grep: can't open pattern file " path) ()))))

; input to lines: split on newline, a trailing newline closing the last
; line rather than opening an empty one (bytes, the x-awk shape)
(def %grep-lines-go
  (fn (self s end i start acc)
    (if (>= i end)
      (if (> i start)
        (reverse (pair (substring s start end) acc))
        (reverse acc))
      (if (= (byte-at s i) 10)
        (self s end (+ i 1) (+ i 1) (pair (substring s start i) acc))
        (self s end (+ i 1) start acc)))))
(def %grep-lines
  (fn (_ s) (%grep-lines-go s (byte-len s) 0 0 ())))

(def %grep-has?
  (fn (_ sym flags)
    (def go
      (fn (self fs)
        (if (null? fs) #f
          (if (eq? (first fs) sym) #t (self (rest fs))))))
    (go flags)))

(def %grep-int->str
  (fn (_ n)
    (if (= n 0) "0"
      (let ((go (fn (self t acc)
                  (if (= t 0) acc
                    (self (/ (- t (% t 10)) 10)
                      (pair (integer->char (+ 48 (% t 10))) acc))))))
        (list->string (go n ()))))))

; --- The run -----------------------------------------------------------------

; One file's worth of lines.  Answers (matched? . early-quit?): quiet
; stops the whole run at the first hit, names stops the file.  NAME is
; the operand (nil for bare stdin); PREFIX? is POSIX's more-than-one-
; file rule.
(def %grep-scan-file
  (fn (_ matchers flags name prefix? lines)
    (def ci (%grep-has? (lit ci) flags))
    (def invert (%grep-has? (lit invert) flags))
    (def quiet (%grep-has? (lit quiet) flags))
    (def names (%grep-has? (lit names) flags))
    (def count (%grep-has? (lit count) flags))
    (def lineno (%grep-has? (lit lineno) flags))
    (def label (if (null? name) "(standard input)" name))
    (def prefix (if prefix? (string-append name ":") ""))
    (def go
      (fn (self ls n hits)
        (if (null? ls)
          (do (if count
                (display (string-append prefix
                           (string-append (%grep-int->str hits) "\n")))
                ())
              (pair (> hits 0) #f))
          (let ((line (first ls)))
            (def lline (if ci (%grep-lower line) ()))
            (def hit (%grep-any-hit? matchers line lline))
            (def sel (if invert (not hit) hit))
            (if (not sel)
              (self (rest ls) (+ n 1) hits)
              (if quiet
                (pair #t #t)
                (if names
                  (do (display (string-append label "\n"))
                      (pair #t #f))
                  ; fallthrough continues below
                  (do (if count ()
                        (display
                          (string-append prefix
                            (string-append
                              (if lineno
                                (string-append (%grep-int->str n) ":")
                                "")
                              (string-append line "\n")))))
                      (self (rest ls) (+ n 1) (+ hits 1))))))))))
    (go lines 1 0)))

; the whole run; INPUT is stdin's text
(def grep-run
  (fn (_ argv input)
    (def plan (grep-parse-cli argv))
    (def flags (first plan))
    (def pats (first (rest plan)))
    (def files (first (rest (rest plan))))
    (if (null? pats)
      (do (file-write 2 "usage: grep [-EFcilnqsvwx] [-e pat]... [-f file]... [pat] [file]...\n")
          2)
      (let ((mode (if (%grep-has? (lit ere) flags) (lit ere)
                    (if (%grep-has? (lit fixed) flags) (lit fixed)
                      (lit bre)))))
        (def matchers
          (map (fn (_ p)
                 (%grep-compile-one p mode
                   (%grep-has? (lit ci) flags)
                   (%grep-has? (lit word) flags)
                   (%grep-has? (lit xline) flags)))
            pats))
        (def many? (if (pair? files) (pair? (rest files)) #f))
        (def scan
          (fn (self fs matched? err?)
            (if (null? fs)
              (if err? 2 (if matched? 0 1))
              (let ((f (first fs)))
                (if (if (not (string=? f "-")) (not (file-exists? f)) #f)
                  (do (if (%grep-has? (lit silent) flags) ()
                        (file-write 2
                          (string-append "grep: can't open "
                            (string-append f "\n"))))
                      (self (rest fs) matched? #t))
                  (let ((text (if (string=? f "-") input
                                (file-read-all f))))
                    (def r (%grep-scan-file matchers flags
                             f many? (%grep-lines text)))
                    (if (rest r)
                      (if err? 2 0)   ; early quit: quiet hit
                      (self (rest fs)
                        (if (first r) #t matched?) err?))))))))
        (if (null? files)
          (let ((r (%grep-scan-file matchers flags () #f
                     (%grep-lines input))))
            (if (first r) 0 1))
          (scan files #f #f))))))
