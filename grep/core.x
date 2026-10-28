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
; turns the name: prefix on, POSIX's rule.  The line loop is shaped on
; busybox 1.36.1's grep_file; where busybox, GNU and BSD grep differ, the
; common ground of GNU and BSD wins: a -- between context groups of
; different files, -o taking the earliest match of any pattern, lines
; past -m's limit kept as trailing context, -r alone walking ".", a
; directory operand without -r refused as one.

; --- Option parsing (pure) ---------------------------------------------------
; The options, declared once: what the parse accepts, what --help prints and
; what a refusal prints.  busybox's grep help text.
(module grep/core)
(import grep/prims integer->char byte-at byte-len substring string=?
  list->string string-append string-concat reverse append map set-first!
  file-read-all file-write file-exists? file-type file-ltype file-list-dir)
(import grep/bre grep-compile-one grep-lower grep-hit grep-hit-at)

(def grep-options
  (Opts declare "grep"
    "[-HhnlLoqvsrRiwFE] [-m N] [-A|B|C N] { PATTERN | -e PATTERN... | -f FILE... } [FILE]..."
    "Search for PATTERN in FILEs (or stdin)"
    (list
      (Opts flag "-H" "Add 'filename:' prefix")
      (Opts flag "-h" "Do not add 'filename:' prefix")
      (Opts flag "-n" "Add 'line_no:' prefix")
      (Opts flag "-l" "Show only names of files that match")
      (Opts flag "-L" "Show only names of files that don't match")
      (Opts flag "-c" "Show only count of matching lines")
      (Opts flag "-o" "Show only the matching part of line")
      (Opts flag "-q" "Quiet. Return 0 if PATTERN is found, 1 otherwise")
      (Opts flag "-v" "Select non-matching lines")
      (Opts flag "-s" "Suppress open and read errors")
      (Opts flag "-r" "Recurse")
      (Opts flag "-R" "Recurse and dereference symlinks")
      (Opts flag "-i" "Ignore case")
      (Opts flag "-w" "Match whole words only")
      (Opts flag "-x" "Match whole lines only")
      (Opts flag "-F" "PATTERN is a literal (not regexp)")
      (Opts flag "-E" "PATTERN is an extended regexp")
      (Opts arg "-m" "N" "Match up to N times per file")
      (Opts arg "-A" "N" "Print N lines of trailing context")
      (Opts arg "-B" "N" "Print N lines of leading context")
      (Opts arg "-C" "N" "Same as '-A N -B N'")
      (Opts arg "-e" "PTRN" "Pattern to match")
      (Opts arg "-f" "FILE" "Read pattern from file"))))

; each flag's name in the run; -H and -h are read apart, the later one wins
(def %grep-flag-syms
  (list (pair "-E" (lit ere)) (pair "-F" (lit fixed))
    (pair "-c" (lit count)) (pair "-i" (lit ci))
    (pair "-l" (lit names)) (pair "-L" (lit unmatched))
    (pair "-n" (lit lineno)) (pair "-o" (lit only))
    (pair "-q" (lit quiet)) (pair "-s" (lit silent))
    (pair "-v" (lit invert)) (pair "-w" (lit word))
    (pair "-x" (lit xline)) (pair "-r" (lit recurse))
    (pair "-R" (lit follow))))

; Answers the plan (FLAGS PATTERNS FILES MAX AFTER BEFORE), flags a symbol
; list and MAX nil without -m; nil when the line does not run: an option
; grep does not take, or no pattern; (invalid-number TOK) for a count that
; is not one.  Options stop at the first operand, as musl's getopt stops;
; -e and -f gather patterns, and without them the first operand is the
; pattern.
(def grep-parse-cli
  (fn (_ argv)
    (def o (Opts parse-leading grep-options argv))
    (def ops (Opts operands o))
    (def from-files
      (fn (self fs)
        (if (null? fs) () (append (%grep-pat-lines (first fs)) (self (rest fs))))))
    (def pats (append (Opts values o "-e") (from-files (Opts values o "-f"))))
    (def bad (%grep-bad-number o))
    (match
      ((not (null? (Opts unknown o))) ())
      ((not (null? bad)) (list (lit invalid-number) bad))
      ((not (null? pats))
        (append (list (%grep-flags o) pats ops) (%grep-counts o)))
      ((null? ops) ())
      (#t (append (list (%grep-flags o) (list (first ops)) (rest ops))
            (%grep-counts o))))))

; the flags given, as symbols, with the later of -H and -h as fname or
; nofname
(def %grep-flags
  (fn (_ o)
    (def go
      (fn (self es)
        (match
          ((null? es) ())
          ((Opts on? o (first (first es))) (pair (rest (first es)) (self (rest es))))
          (#t (self (rest es))))))
    (def hh (%grep-last-of (Assoc get (lit on) o) "-H" "-h" ()))
    (if (null? hh) (go %grep-flag-syms)
      (pair (if (string=? hh "-H") (lit fname) (lit nofname)) (go %grep-flag-syms)))))

; the later of A and B in the option list GIVEN, or ELSE
(def %grep-last-of
  (fn (self given a b else)
    (match
      ((null? given) else)
      ((string=? (first given) a) (self (rest given) a b a))
      ((string=? (first given) b) (self (rest given) a b b))
      (#t (self (rest given) a b else)))))

; the first -m, -A, -B or -C argument that is not a number, in the order
; given, or nil
(def %grep-bad-number
  (fn (_ o)
    (def go
      (fn (self vs)
        (match
          ((null? vs) ())
          ((not (%grep-member? (first (first vs)) (list "-m" "-A" "-B" "-C")))
            (self (rest vs)))
          ((null? (%grep-number (rest (first vs)))) (rest (first vs)))
          (#t (self (rest vs))))))
    (go (Assoc get (lit values) o))))

; (MAX AFTER BEFORE): -m's last value or nil; -A and -B each the later of
; itself and -C, as busybox's "-C unsets -A and -B" reads once the line is
; parsed; 0 when neither was given
(def %grep-counts
  (fn (_ o)
    (def vs (Assoc get (lit values) o))
    (def last-of
      (fn (self es a b hit)
        (match
          ((null? es) hit)
          ((string=? (first (first es)) a) (self (rest es) a b (rest (first es))))
          ((string=? (first (first es)) b) (self (rest es) a b (rest (first es))))
          (#t (self (rest es) a b hit)))))
    (def m (Opts value o "-m"))
    (def after (last-of vs "-A" "-C" ()))
    (def before (last-of vs "-B" "-C" ()))
    (list (if (null? m) () (%grep-number m))
      (if (null? after) 0 (%grep-number after))
      (if (null? before) 0 (%grep-number before)))))

; a decimal count as busybox's xatoi_positive reads it: digits only
(def %grep-number
  (fn (_ s)
    (def end (byte-len s))
    (def go
      (fn (self i acc)
        (match
          ((>= i end) acc)
          ((if (>= (byte-at s i) 48) (<= (byte-at s i) 57) #f)
            (self (+ i 1) (+ (* acc 10) (- (byte-at s i) 48))))
          (#t ()))))
    (if (= end 0) () (go 0 0))))

; The line refused, as busybox's grep refuses it: musl getopt's line naming the
; option, or nothing when there was no pattern, then the usage text, on
; standard error, and 2.
(def %grep-refuse
  (fn (_ tok)
    (do (unless (null? tok)
          (file-write 2 (string-concat (list "grep: " (%grep-refusal tok) "\n"))))
        (file-write 2 (Opts usage grep-options))
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
            ((%grep-member? opt (Opts valued grep-options))
              (string-append "option requires an argument: " (substring tok i (+ i 1))))
            ((%grep-member? opt (Opts flags grep-options)) (self (+ i 1)))
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
      (grep-lines (file-read-all path))
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
(def grep-lines
  (fn (_ s) (%grep-lines-go s (byte-len s) 0 0 ())))

(def %grep-has?
  (fn (_ sym flags)
    (def go
      (fn (self fs)
        (match
          ((null? fs) #f)
          ((eq? (first fs) sym) #t)
          (#t (self (rest fs))))))
    (go flags)))

(def %grep-int->str
  (fn (_ n)
    (if (= n 0) "0"
      (let ((go (fn (self t acc)
                  (if (= t 0) acc
                    (self (/ (- t (% t 10)) 10)
                      (pair (integer->char (+ 48 (% t 10))) acc))))))
        (list->string (go n ()))))))

; the first N of a list
(def %grep-take
  (fn (self l n)
    (if (if (null? l) #t (<= n 0)) ()
      (pair (first l) (self (rest l) (- n 1))))))

; the file operands of a plan, or nothing for a line that does not run
(def grep-plan-files
  (fn (_ plan)
    (if (if (null? plan) #t (eq? (first plan) (lit invalid-number))) ()
      (first (rest (rest plan))))))

; DIR/NAME, one slash between them whatever DIR ends with
(def %grep-subpath
  (fn (_ dir name)
    (if (= (byte-at dir (- (byte-len dir) 1)) 47)
      (string-append dir name)
      (string-concat (list dir "/" name)))))

; the text after "SYSCALL: " in a platform io Err's message, or the message
(def %grep-errno-text
  (fn (_ msg)
    (def end (byte-len msg))
    (def go
      (fn (self i)
        (match
          ((>= (+ i 1) end) msg)
          ((if (= (byte-at msg i) 58) (= (byte-at msg (+ i 1)) 32) #f)
            (substring msg (+ i 2) end))
          (#t (self (+ i 1))))))
    (go 0)))

; --- The run -----------------------------------------------------------------

; the whole run; INPUT is stdin's text
(def grep-run
  (fn (_ argv input)
    (def plan (if (Opts help? grep-options argv) () (grep-parse-cli argv)))
    (match
      ((Opts help? grep-options argv)
        (do (file-write 1 (Opts usage grep-options)) 0))
      ((null? plan)
        (%grep-refuse (Opts unknown (Opts parse-leading grep-options argv))))
      ((eq? (first plan) (lit invalid-number))
        (do (file-write 2
              (string-concat (list "grep: invalid number '" (first (rest plan)) "'\n")))
            2))
      (#t (%grep-go plan input)))))

; The run's settings, read once from the plan as an alist the builders
; below destructure on entry.  -c -q -l -L print no lines, so -n and the
; context go with them; -r with no operand walks ".".
(def %grep-settings
  (fn (_ plan)
    (def flags (first plan))
    (def counts (rest (rest (rest plan))))
    (def has? (fn (_ sym) (%grep-has? sym flags)))
    (def count (has? (lit count)))
    (def quiet (has? (lit quiet)))
    (def names (has? (lit names)))
    (def unmatched (has? (lit unmatched)))
    (def bare (match (count #t) (quiet #t) (names #t) (#t unmatched)))
    (def after (if bare 0 (first (rest counts))))
    (def before (if bare 0 (first (rest (rest counts)))))
    (def ci (has? (lit ci)))
    (def label (if (has? (lit ere)) (lit ere)
                 (if (has? (lit fixed)) (lit fixed) (lit bre))))
    (def recurse (if (has? (lit recurse)) #t (has? (lit follow))))
    (def files (first (rest (rest plan))))
    (list
      (pair (lit ms) (map (fn (_ p) (grep-compile-one p label ci)) (first (rest plan))))
      (pair (lit files) (if (if recurse (null? files) #f) (list ".") files))
      (pair (lit max) (first counts))
      (pair (lit after) after)
      (pair (lit before) before)
      (pair (lit context) (if (> after 0) #t (> before 0)))
      (pair (lit count) count)
      (pair (lit quiet) quiet)
      (pair (lit names) names)
      (pair (lit unmatched) unmatched)
      (pair (lit lineno) (if bare #f (has? (lit lineno))))
      (pair (lit silent) (has? (lit silent)))
      (pair (lit only) (has? (lit only)))
      (pair (lit invert) (has? (lit invert)))
      (pair (lit ci) ci)
      (pair (lit word) (has? (lit word)))
      (pair (lit xline) (has? (lit xline)))
      (pair (lit follow) (has? (lit follow)))
      (pair (lit recurse) recurse)
      (pair (lit nofname) (has? (lit nofname)))
      (pair (lit fname) (has? (lit fname))))))

(def %grep-setting
  (fn (_ s key) (Assoc get key s)))

; The line printer: a -- between context groups that are not adjacent,
; or belong to different files, then the name and number with DECO, then
; the line.  Answers (PRINT-LINE START-FILE!): the scanner calls the
; second at each file so the first group of a new file gets its --.
(def %grep-printer
  (fn (_ s)
    (def context (%grep-setting s (lit context)))
    (def lineno (%grep-setting s (lit lineno)))
    (def did-print (pair #f ()))
    ; the last line printed, or nothing yet in this file
    (def last-printed (pair () ()))
    (def separate?
      (fn (_ linenum)
        (match
          ((not context) #f)
          ((not (first did-print)) #f)
          ((null? (first last-printed)) #t)
          (#t (not (= (first last-printed) (- linenum 1)))))))
    (def print-line
      (fn (_ prefix? name line linenum deco)
        (if (separate? linenum) (display "--\n") ())
        (set-first! did-print #t)
        (set-first! last-printed linenum)
        (display
          (string-concat
            (list (if prefix? (string-append name deco) "")
              (if lineno (string-append (%grep-int->str linenum) deco) "")
              line "\n")))))
    (list print-line (fn (_) (set-first! last-printed ())))))

; -o on a selected line: each match of any pattern in turn, the earliest
; next, an empty one skipped and stepped over; nothing for a line -v
; selected, which has none
(def %grep-only-printer
  (fn (_ s print-line)
    (def ms (%grep-setting s (lit ms)))
    (def word (%grep-setting s (lit word)))
    (def xline (%grep-setting s (lit xline)))
    (def only-next
      (fn (_ again prefix? name line lline linenum from)
        (def hit (grep-hit-at ms line lline word xline from ()))
        (if (null? hit) ()
          (again prefix? name line lline linenum (first (rest hit)) (first (rest (rest hit)))))))
    (def only-loop
      (fn (self prefix? name line lline linenum so eo)
        (def len (- eo so))
        (if (> len 0) (print-line prefix? name (substring line so eo) linenum ":") ())
        (if (>= eo (byte-len line)) ()
          (only-next self prefix? name line lline linenum (if (= len 0) (+ eo 1) eo)))))
    (fn (_ prefix? name line lline linenum)
      (only-next only-loop prefix? name line lline linenum 0))))

(def %grep-say-name
  (fn (_ name answer)
    (display (string-append name "\n"))
    answer))

; a file's end: the count, then -L's name; answers whether the file
; counts as matched
(def %grep-finisher
  (fn (_ s)
    (def count (%grep-setting s (lit count)))
    (def unmatched (%grep-setting s (lit unmatched)))
    (fn (_ prefix? name nmatches)
      (if count
        (display (string-concat
                   (list (if prefix? (string-append name ":") "")
                     (%grep-int->str nmatches) "\n")))
        ())
      (if unmatched
        (%grep-say-name name #t)
        (> nmatches 0)))))

; One file's lines, busybox's grep_file.  The scanner answers quit (a -q
; hit ends the run), #t (matched) or #f.  N is the number of the last line
; read, NMATCHES the selected lines so far, N-AFTER the trailing context
; still owed, BEF the lines held for leading context, newest first.  Each
; local is defined before the one that names it, the later of two that
; call each other handed in as AGAIN.
(def %grep-scanner
  (fn (_ s print-line start-file! only-out finish)
    (def ms (%grep-setting s (lit ms)))
    (def max (%grep-setting s (lit max)))
    (def max? (not (null? max)))
    (def after (%grep-setting s (lit after)))
    (def before (%grep-setting s (lit before)))
    (def count (%grep-setting s (lit count)))
    (def quiet (%grep-setting s (lit quiet)))
    (def names (%grep-setting s (lit names)))
    (def unmatched (%grep-setting s (lit unmatched)))
    (def only (%grep-setting s (lit only)))
    (def invert (%grep-setting s (lit invert)))
    (def ci (%grep-setting s (lit ci)))
    (def word (%grep-setting s (lit word)))
    (def xline (%grep-setting s (lit xline)))
    ; the leading context, oldest first, each line with its number
    (def print-before-one
      (fn (_ again prefix? name bef)
        (print-line prefix? name (rest (first bef)) (first (first bef)) "-")
        (again prefix? name (rest bef))))
    (def print-before
      (fn (self prefix? name bef)
        (if (null? bef) ()
          (print-before-one self prefix? name bef))))
    (def emit
      (fn (_ prefix? name bef line lline ln)
        (print-before prefix? name (reverse bef))
        (if only
          (only-out prefix? name line lline ln)
          (print-line prefix? name line ln ":"))))
    ; on to the next line
    (def next
      (fn (_ again prefix? name ls ln nmatches n-after bef)
        (again prefix? name (rest ls) ln nmatches n-after bef)))
    (def after-one
      (fn (_ again prefix? name ls ln nmatches n-after bef line)
        (print-line prefix? name line ln "-")
        (next again prefix? name ls ln nmatches (- n-after 1) bef)))
    (def unselected
      (fn (_ again prefix? name ls ln nmatches n-after bef line)
        (match
          ((> n-after 0)
            (after-one again prefix? name ls ln nmatches n-after bef line))
          ((> before 0)
            (next again prefix? name ls ln nmatches 0
              (%grep-take (pair (pair ln line) bef) before)))
          (#t (next again prefix? name ls ln nmatches 0 bef)))))
    (def selected
      (fn (_ again prefix? name ls ln nmatches bef line lline)
        (if count () (emit prefix? name bef line lline ln))
        (next again prefix? name ls ln nmatches after ())))
    (def step
      (fn (_ again prefix? name ls n nmatches n-after bef)
        (def line (first ls))
        (def ln (+ n 1))
        (def lline (if ci (grep-lower line) ()))
        (def hit (grep-hit ms line lline word xline))
        (def sel (if invert (null? hit) (not (null? hit))))
        (match
          ((not sel) (unselected again prefix? name ls ln nmatches n-after bef line))
          (quiet (lit quit))
          (names (%grep-say-name name #t))
          (unmatched #f)
          ; a selected line past -m's limit is trailing context at most
          ((if max? (>= nmatches max) #f)
            (unselected again prefix? name ls ln nmatches n-after bef line))
          (#t (selected again prefix? name ls ln (+ nmatches 1) bef line lline)))))
    ; the file is done at its last line, or once -m's matches are in and
    ; their trailing context out
    (def go
      (fn (self prefix? name ls n nmatches n-after bef)
        (match
          ((null? ls) (finish prefix? name nmatches))
          ((if max? (if (= n-after 0) (>= nmatches max) #f) #f)
            (finish prefix? name nmatches))
          (#t (step self prefix? name ls n nmatches n-after bef)))))
    (fn (_ prefix? name lines)
      (start-file!)
      (go prefix? name lines 0 0 0 ()))))

; "grep: PATH: WHY\n"
(def %grep-complaint
  (fn (_ path why)
    (string-concat (list "grep: " path ": " why "\n"))))

; The operands: the loop over them, with grep_dir and
; file_action_grep under -r.  The walker answers the run's status.  The
; name prefix is threaded: a directory under -r turns it on for the rest
; of the run, unless -h.
(def %grep-walker
  (fn (_ s scan-file input)
    (def silent (%grep-setting s (lit silent)))
    (def recurse (%grep-setting s (lit recurse)))
    (def follow (%grep-setting s (lit follow)))
    (def nofname (%grep-setting s (lit nofname)))
    (def open-errors (pair #f ()))
    (def complain
      (fn (_ path why)
        (if silent () (file-write 2 (%grep-complaint path why)))))
    (def open-error!
      (fn (_ path why)
        (complain path why)
        (set-first! open-errors #t)
        #f))
    (def read-error!
      (fn (_ path e)
        (open-error! path
          (%grep-errno-text (if (Err err? e) (e msg) (Err code-of e))))))
    ; a file opened and read; an open error is reported and remembered
    ; for the status.  Answers scan-file's answer, or #f when it would not
    ; open.
    (def grep-path
      (fn (_ prefix? path)
        (def text (guard (e (read-error! path e)) (file-read-all path)))
        (if (null? text) #f
          (scan-file prefix? path (grep-lines text)))))
    ; busybox's file_action_grep: a link is looked through, and one to a
    ; directory or to nothing is passed over
    (def visit-file
      (fn (_ prefix? path kind)
        (def target (if (eq? kind (lit link)) (file-type path) kind))
        (match
          ((null? target) (do (complain path "No such file or directory") #f))
          ((eq? target (lit dir)) #f)
          (#t (grep-path prefix? path)))))
    ; a directory entry that went away between the listing and the look:
    ; said whatever -s says, and not an open error
    (def gone
      (fn (_ path)
        (file-write 2 (%grep-complaint path "No such file or directory"))
        #f))
    ; busybox's recursive_action over a directory: each entry in the
    ; kernel's order, a subdirectory (or, under -R, a link to one) walked,
    ; the rest visited.  Answers quit, #t when any file matched, else #f.
    (def visit
      (fn (_ walk prefix? path)
        (def kind (if follow (file-type path) (file-ltype path)))
        (match
          ((null? kind) (gone path))
          ((eq? kind (lit dir)) (walk prefix? path (file-list-dir path) #f))
          (#t (visit-file prefix? path kind)))))
    (def entries
      (fn (self prefix? dir es matched)
        (if (null? es) matched
          (%grep-entry self prefix? dir es matched
            (visit self prefix? (%grep-subpath dir (first es)))))))
    (def grep-dir
      (fn (_ prefix? dir)
        (entries prefix? dir (file-list-dir dir) #f)))
    ; One operand.  Answers (RESULT . PREFIX?).
    (def operand
      (fn (_ prefix? f)
        (def kind (if (string=? f "-") () (file-type f)))
        (match
          ((string=? f "-")
            (pair (scan-file prefix? "(standard input)" (grep-lines input)) prefix?))
          ((if recurse (eq? kind (lit dir)) #f)
            (pair (grep-dir (if nofname prefix? #t) f) (if nofname prefix? #t)))
          ((null? kind)
            (pair (open-error! f "No such file or directory") prefix?))
          ((eq? kind (lit dir)) (pair (open-error! f "Is a directory") prefix?))
          (#t (pair (grep-path prefix? f) prefix?)))))
    (def status
      (fn (_ matched)
        (if (first open-errors) 2 (if matched 0 1))))
    (def scan-one
      (fn (_ again fs matched prefix?)
        (def r (operand prefix? (first fs)))
        (if (eq? (first r) (lit quit)) 0
          (again (rest fs) (if (first r) #t matched) (rest r)))))
    (def scan
      (fn (self fs matched prefix?)
        (if (null? fs) (status matched)
          (scan-one self fs matched prefix?))))
    (def prefix0
      (match
        ((%grep-setting s (lit fname)) #t)
        (nofname #f)
        (#t (let ((fs (%grep-setting s (lit files))))
              (if (pair? fs) (pair? (rest fs)) #f)))))
    (fn (_ files)
      (if (null? files)
        (let ((r (scan-file prefix0 "(standard input)" (grep-lines input))))
          (if (eq? r (lit quit)) 0 (status r)))
        (scan files #f prefix0)))))

; the rest of a directory's entries after one answered R: a quit ends the
; walk, a match is remembered
(def %grep-entry
  (fn (_ again prefix? dir es matched r)
    (if (eq? r (lit quit)) r
      (again prefix? dir (rest es) (if r #t matched)))))

; A planned run: the settings, the printers and the scanner built on
; them, and the walk over the operands.
(def %grep-go
  (fn (_ plan input)
    (def s (%grep-settings plan))
    (def printer (%grep-printer s))
    (def print-line (first printer))
    (def scan-file
      (%grep-scanner s print-line (first (rest printer))
        (%grep-only-printer s print-line) (%grep-finisher s)))
    ((%grep-walker s scan-file input) (%grep-setting s (lit files)))))

(provide grep/core grep-run grep-parse-cli grep-options grep-lines grep-plan-files)
