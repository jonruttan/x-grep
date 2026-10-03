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
; The options, declared once: what the parse accepts, what --help prints and
; what a refusal prints.  busybox's grep help text, less the rows for the
; options this grep does not take (-H -h -L -o -r -R -m -A -B -C).
(def %grep-options
  (Opts declare "grep"
    "[-HhnlLoqvsrRiwFE] [-m N] [-A|B|C N] { PATTERN | -e PATTERN... | -f FILE... } [FILE]..."
    "Search for PATTERN in FILEs (or stdin)"
    (list
      (Opts flag "-n" "Add 'line_no:' prefix")
      (Opts flag "-l" "Show only names of files that match")
      (Opts flag "-c" "Show only count of matching lines")
      (Opts flag "-q" "Quiet. Return 0 if PATTERN is found, 1 otherwise")
      (Opts flag "-s" "Suppress open and read errors")
      (Opts flag "-v" "Select non-matching lines")
      (Opts flag "-i" "Ignore case")
      (Opts flag "-w" "Match whole words only")
      (Opts flag "-x" "Match whole lines only")
      (Opts flag "-F" "PATTERN is a literal (not regexp)")
      (Opts flag "-E" "PATTERN is an extended regexp")
      (Opts arg "-e" "PTRN" "Pattern to match")
      (Opts arg "-f" "FILE" "Read pattern from file"))))

; each flag's name in the run
(def %grep-flag-syms
  (list (pair "-E" (lit ere)) (pair "-F" (lit fixed))
    (pair "-c" (lit count)) (pair "-i" (lit ci))
    (pair "-l" (lit names)) (pair "-n" (lit lineno))
    (pair "-q" (lit quiet)) (pair "-s" (lit silent))
    (pair "-v" (lit invert)) (pair "-w" (lit word))
    (pair "-x" (lit xline))))

; Answers ((flags) (patterns) (files)), flags a symbol list, or nil when the
; line does not run: an option grep does not take, or no pattern.  Options
; stop at the first operand, as musl's getopt stops; -e and -f gather
; patterns, and without them the first operand is the pattern.
(def grep-parse-cli
  (fn (_ argv)
    (def o (Opts parse-leading %grep-options argv))
    (def ops (Opts operands o))
    (def from-files
      (fn (self fs)
        (if (null? fs) () (append (%grep-pat-lines (first fs)) (self (rest fs))))))
    (def pats (append (Opts values o "-e") (from-files (Opts values o "-f"))))
    (match
      ((not (null? (Opts unknown o))) ())
      ((not (null? pats))
        (list (%grep-flags o) pats ops))
      ((null? ops) ())
      (#t (list (%grep-flags o) (list (first ops)) (rest ops))))))

(def %grep-flags
  (fn (_ o)
    (def go
      (fn (self es)
        (match
          ((null? es) ())
          ((Opts on? o (first (first es))) (pair (rest (first es)) (self (rest es))))
          (#t (self (rest es))))))
    (go %grep-flag-syms)))

; The line refused, as busybox's grep refuses it: musl getopt's line naming the
; option, or nothing when there was no pattern, then the usage text, on
; standard error, and 2.
(def %grep-refuse
  (fn (_ tok)
    (do (unless (null? tok)
          (file-write 2 (string-concat (list "grep: " (%grep-refusal tok) "\n"))))
        (file-write 2 (Opts usage %grep-options))
        2)))

; What is wrong with TOK, in musl getopt's words: in a short cluster, read left
; to right, the first letter grep does not take is unrecognized, and -e or -f
; with nothing after it requires an argument; a long option is named without
; its dashes.
(def %grep-refusal
  (fn (_ tok)
    (def end (byte-len tok))
    (def go
      (fn (self i)
        (let ((opt (string-append "-" (substring tok i (+ i 1)))))
          (match
            ((>= i end) (string-append "unrecognized option: " (substring tok 1 end)))
            ((%grep-member? opt (Opts valued %grep-options))
              (string-append "option requires an argument: " (substring tok i (+ i 1))))
            ((%grep-member? opt (Opts flags %grep-options)) (self (+ i 1)))
            (#t (string-append "unrecognized option: " (substring tok i (+ i 1))))))))
    (if (if (> end 2) (= (byte-at tok 1) #\-) #f)
      (string-append "unrecognized option: " (substring tok 2 end))
      (go 1))))

(def %grep-member?
  (fn (self s l)
    (if (null? l) #f (if (string=? (first l) s) #t (self s (rest l))))))

; a -f file: one pattern per line
(def %grep-pat-lines
  (fn (_ path)
    (if (file-exists? path)
      (%grep-lines (file-read-all path))
      (Err raise (lit grep)
        (string-append "grep: can't open pattern file " path) ()))))

; input to lines: split on newline, a trailing newline closing the last
; line rather than opening an empty one (bytes, the x-awk pattern)
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
    (def shown-name (if (null? name) "(standard input)" name))
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
                  (do (display (string-append shown-name "\n"))
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
    (def plan (if (Opts help? %grep-options argv) () (grep-parse-cli argv)))
    (def flags (if (null? plan) () (first plan)))
    (def pats (if (null? plan) () (first (rest plan))))
    (def files (if (null? plan) () (first (rest (rest plan)))))
    (match
      ((Opts help? %grep-options argv)
        (do (file-write 1 (Opts usage %grep-options)) 0))
      ((null? plan)
        (%grep-refuse (Opts unknown (Opts parse-leading %grep-options argv))))
      (#t
      (let ((label (if (%grep-has? (lit ere) flags) (lit ere)
                    (if (%grep-has? (lit fixed) flags) (lit fixed)
                      (lit bre)))))
        (def matchers
          (map (fn (_ p)
                 (%grep-compile-one p label
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
          (scan files #f #f)))))))
