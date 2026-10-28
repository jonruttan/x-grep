; # x-grep -- POSIX grep on x-lang
;
; ## grep/bre.x -- patterns to matchers
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; POSIX grep speaks BRE by default, where ( ) { } + ? | are literal and \( \)
; \{ \} \| \+ \? are the operators (the last three the extension GNU, BSD
; and busybox grep share); lib/x/type/regex.x speaks an ERE-like dialect.
; So BRE translates by swapping the escapes: bare operator characters gain
; a backslash, the backslashed operators lose theirs. -E passes through.
; Case-insensitivity is compiled into the pattern -- a literal letter becomes
; its two-case class, a class entry gains its swapped twin -- so no engine flag
; is needed.  A [:named:] class expands inside its bracket to the bytes it
; stands for, in the engine's own class syntax.
;
; -w and -x are loops around a match, not part of the pattern: a match
; whose neighbours are word bytes is retried from its end, and -x wants
; the match to be the whole line.  Every matcher answers its first
; admitted match at or after a position, so -o can walk a line taking the
; earliest match of any pattern each time, as GNU and BSD grep print it.
;
; Refused loudly, because a loud error beats a silent wrong match:
; back-references \1-\9 (the engine cannot).

; case-swap a letter byte, else nil
(module grep/bre)
(import grep/prims integer->char byte-at byte-len string=? list->string
  string-append string-concat substring reverse regex-compile regex-find-at
  regex-match)

(def %grep-swap
  (fn (_ b)
    (if (if (>= b 97) (<= b 122) #f) (- b 32)
      (if (if (>= b 65) (<= b 90) #f) (+ b 32) ()))))

(def grep-b->s
  (fn (_ b) (list->string (list (integer->char b)))))

; the engine's escapables that mean a CLASS, not a literal -- do not
; case-expand these
(def %grep-esc-special?
  (fn (_ b)
    (match
      ((= b 98) #t)  ((= b 66) #t)           ; b B
      ((= b 100) #t) ((= b 68) #t)           ; d D
      ((= b 115) #t) ((= b 83) #t)           ; s S
      ((= b 119) #t) ((= b 87) #t)           ; w W
      (#t #f))))

; regcomp's complaint about PAT, in busybox's words
(def %grep-bad-regex
  (fn (_ pat what)
    (Err raise (lit grep)
      (string-concat (list "grep: bad regex '" pat "': " what)) pat)))

; A [:NAME:] class as the engine's class entries: the ranges in the C
; locale, both cases of a cased class under -i (regcomp's REG_ICASE does the
; same).  nil for a name regcomp does not know.
(def %grep-named-class
  (fn (_ name ci)
    (match
      ((string=? name "alpha") "a-zA-Z")
      ((string=? name "digit") "0-9")
      ((string=? name "alnum") "a-zA-Z0-9")
      ((string=? name "upper") (if ci "A-Za-z" "A-Z"))
      ((string=? name "lower") (if ci "a-zA-Z" "a-z"))
      ((string=? name "space")
        (string-concat (list (grep-b->s 9) "-" (grep-b->s 13) " ")))
      ((string=? name "blank") (string-append " " (grep-b->s 9)))
      ((string=? name "punct") "!-/:-@[-`{-~")
      ((string=? name "xdigit") "0-9A-Fa-f")
      ((string=? name "cntrl")
        (string-concat (list (grep-b->s 1) "-" (grep-b->s 31) (grep-b->s 127))))
      ((string=? name "print") (string-append " -" (grep-b->s 126)))
      ((string=? name "graph") (string-append "!-" (grep-b->s 126)))
      (#t ()))))

; the index of ":]" at or after I, or -1
(def %grep-class-close
  (fn (self pat end i)
    (match
      ((>= (+ i 1) end) -1)
      ((if (= (byte-at pat i) 58) (= (byte-at pat (+ i 1)) 93) #f) i)
      (#t (self pat end (+ i 1))))))

; Copy a [...] class, expanding case when ci: each letter (or letter
; range) also emits its swapped twin, and a [:named:] class its bytes.
; Answers (pieces . next-i), pieces reversed.
(def %grep-xl-class
  (fn (_ pat end i0 ci acc0)
    (def go
      (fn (self i acc first?)
        (if (>= i end)
          (%grep-bad-regex pat "Missing ']'")
          (let ((b (byte-at pat i)))
            (match
              ((if (= b 93) (not first?) #f)              ; closing ]
                (pair (pair "]" acc) (+ i 1)))
              ((if (= b 91)                               ; [: ?
                 (if (< (+ i 1) end) (= (byte-at pat (+ i 1)) 58) #f)
                 #f)
                (let ((close (%grep-class-close pat end (+ i 2))))
                  (def piece
                    (if (< close 0) ()
                      (%grep-named-class (substring pat (+ i 2) close) ci)))
                  (if (null? piece)
                    (%grep-bad-regex pat "Unknown character class name")
                    (self (+ close 2) (pair piece acc) #f))))
              ((if (< (+ i 2) end)                        ; a-b range?
                 (if (= (byte-at pat (+ i 1)) 45)         ; -
                   (not (= (byte-at pat (+ i 2)) 93))
                   #f)
                 #f)
                (let ((lo b))
                  (def hi (byte-at pat (+ i 2)))
                  (def piece
                    (string-append (grep-b->s lo) "-" (grep-b->s hi)))
                  (def swl (%grep-swap lo))
                  (def swh (%grep-swap hi))
                  (self (+ i 3)
                    (if (if ci (not (null? swl)) #f)
                      (pair (string-append (grep-b->s swl) "-"
                              (grep-b->s (if (null? swh) hi swh)))
                        (pair piece acc))
                      (pair piece acc))
                    #f)))
              (#t
                (let ((sw (%grep-swap b)))
                  (self (+ i 1)
                    (if (if ci (not (null? sw)) #f)
                      (pair (grep-b->s sw) (pair (grep-b->s b) acc))
                      (pair (grep-b->s b) acc))
                    #f))))))))
    ; leading ^ and a first-position ] are literal parts of the class
    (def i1 (if (if (< i0 end) (= (byte-at pat i0) 94) #f) (+ i0 1) i0))
    (def acc1 (if (= i1 i0) (pair "[" acc0) (pair "[^" acc0)))
    (go i1 acc1 #t)))

; One literal byte, case-expanded when ci and a letter.
(def %grep-xl-lit
  (fn (_ b ci acc)
    (let ((sw (if ci (%grep-swap b) ())))
      (if (null? sw)
        (pair (grep-b->s b) acc)
        (pair (string-append "[" (grep-b->s b) (grep-b->s sw) "]") acc)))))

; The translator: BRE or ERE text to the engine's dialect.
(def grep-xlate
  (fn (_ pat bre? ci)
    (def end (byte-len pat))
    (def go
      (fn (self i acc)
        (if (>= i end) (string-concat (reverse acc))
          (let ((b (byte-at pat i)))
            (match
              ((= b 91)                                    ; [
                (let ((r (%grep-xl-class pat end (+ i 1) ci acc)))
                  (self (rest r) (first r))))
              ((= b 92)                                    ; backslash
                (if (>= (+ i 1) end)
                  (self (+ i 1) (pair "\\\\" acc))
                  (let ((e (byte-at pat (+ i 1))))
                    (match
                      ((if (>= e 49) (<= e 57) #f)         ; \1-\9
                        (Err raise (lit grep)
                          "grep: back-references are not supported" pat))
                      ((if bre?
                         (match ((= e 40) #t) ((= e 41) #t)
                                ((= e 123) #t) ((= e 125) #t)
                                ((= e 124) #t) ((= e 43) #t)
                                ((= e 63) #t) (#t #f))
                         #f)
                        ; BRE \( \) \{ \} \| \+ \? are the OPERATORS: unescape
                        (self (+ i 2) (pair (grep-b->s e) acc)))
                      ((if ci
                         (if (null? (%grep-swap e)) #f
                           (not (%grep-esc-special? e)))
                         #f)
                        ; escaped plain letter under -i: two-case class
                        (self (+ i 2) (%grep-xl-lit e ci acc)))
                      (#t
                        (self (+ i 2)
                          (pair (string-append "\\" (grep-b->s e))
                            acc)))))))
              ((if bre?
                 (match ((= b 40) #t) ((= b 41) #t)
                        ((= b 123) #t) ((= b 125) #t)
                        ((= b 43) #t)  ((= b 63) #t)
                        ((= b 124) #t) (#t #f))
                 #f)
                ; BRE bare ( ) { } + ? | are LITERAL: escape for the engine
                (self (+ i 1)
                  (pair (string-append "\\" (grep-b->s b)) acc)))
              ((if (null? (%grep-swap b)) #t (not ci))
                (self (+ i 1) (pair (grep-b->s b) acc)))
              (#t (self (+ i 1) (%grep-xl-lit b ci acc))))))))
    (go 0 ())))

; The pure translation door the specs exercise.
(def grep-xlate-bre
  (fn (_ pat) (grep-xlate pat #t #f)))

; lowercase a whole string, bytewise (-F -i)
(def grep-lower
  (fn (_ s)
    (def end (byte-len s))
    (def go
      (fn (self i acc)
        (if (>= i end) (list->string (reverse acc))
          (let ((b (byte-at s i)))
            (self (+ i 1)
              (pair (integer->char
                      (if (if (>= b 65) (<= b 90) #f) (+ b 32) b))
                acc))))))
    (go 0 ())))

; One pattern to a matcher: (LABEL DATA TEXT), where LABEL is rx (a
; compiled regex) or fix (a literal, pre-lowered under -i so the line
; lowers at match time) and TEXT is the pattern as given, what -oF prints.
(def grep-compile-one
  (fn (_ pat label ci)
    (if (eq? label (lit fixed))
      (list (lit fix) (if ci (grep-lower pat) pat) pat)
      (list (lit rx) (regex-compile (grep-xlate pat (eq? label (lit bre)) ci))
        pat))))

; busybox's word byte: isalnum or _
(def %grep-word-byte?
  (fn (_ b)
    (match
      ((if (>= b 48) (<= b 57) #f) #t)
      ((if (>= b 65) (<= b 90) #f) #t)
      ((if (>= b 97) (<= b 122) #f) #t)
      (#t (= b 95)))))

; -w's test around a match at SO..EO of LINE (LEN bytes): neither
; neighbour is a word byte, a space standing in past the ends
(def %grep-word-fit?
  (fn (_ line len so eo)
    (if (%grep-word-byte? (if (> so 0) (byte-at line (- so 1)) 32)) #f
      (not (%grep-word-byte? (if (< eo len) (byte-at line eo) 32))))))

; The first match of RX in LINE at or after AT that -w and -x admit, as
; (so eo), or nil.  -w retries from the end of a match that sits against
; a word byte, as long as the match moved; -x asks the engine for the
; whole line, so a leftmost-first engine still finds the long alternative.
(def %grep-rx-hit
  (fn (_ rx line word xline at)
    (def len (byte-len line))
    (def go
      (fn (self from)
        (def m (regex-find-at line from rx))
        (match
          ((null? m) ())
          ((not word) m)
          ((%grep-word-fit? line len (first m) (first (rest m))) m)
          ((> (first (rest m)) from) (self (first (rest m))))
          (#t ()))))
    (if xline
      (if (if (= at 0) (regex-match line rx) #f) (list 0 len) ())
      (go at))))

; the index of NEEDLE in HAY at or after AT, bytes, or -1
(def %grep-find-from
  (fn (_ hay needle at)
    (def ls (byte-len hay))
    (def lt (byte-len needle))
    (def hit?
      (fn (self i j)
        (if (>= j lt) #t
          (if (= (byte-at hay (+ i j)) (byte-at needle j))
            (self i (+ j 1))
            #f))))
    (def go
      (fn (self i)
        (if (> (+ i lt) ls) -1
          (if (hit? i 0) i (self (+ i 1))))))
    (go at)))

; The first occurrence of NEEDLE in HAY at or after AT that -w and -x
; admit, as (so eo), or nil.  -x wants the occurrence to be the whole
; line; -w retries one byte on.
(def %grep-fix-hit
  (fn (_ needle hay word xline at)
    (def len (byte-len hay))
    (def nlen (byte-len needle))
    (def go
      (fn (self from)
        (def so (%grep-find-from hay needle from))
        (match
          ((< so 0) ())
          (xline (if (if (= so 0) (= nlen len) #f) (list 0 len) ()))
          ((not word) (list so (+ so nlen)))
          ((%grep-word-fit? hay len so (+ so nlen)) (list so (+ so nlen)))
          (#t (self (+ so 1))))))
    (go at)))

; one matcher's first admitted match at or after AT; LLINE is the lowered
; line fixed matchers see under -i, nil otherwise
(def %grep-match-at
  (fn (_ m line lline word xline at)
    (if (eq? (first m) (lit rx))
      (%grep-rx-hit (first (rest m)) line word xline at)
      (%grep-fix-hit (first (rest m)) (if (null? lline) line lline) word xline at))))

; Does LINE satisfy one of MATCHERS?  Answers (matcher so eo) for the
; first that does, or nil -- selection stops at the first.
(def %grep-hit-one
  (fn (_ again ms line lline word xline)
    (def p (%grep-match-at (first ms) line lline word xline 0))
    (if (null? p) (again (rest ms) line lline word xline) (pair (first ms) p))))

(def grep-hit
  (fn (self ms line lline word xline)
    (if (null? ms) ()
      (%grep-hit-one self ms line lline word xline))))

; The earliest match of any of MATCHERS at or after AT, the longest when
; two start together, as (matcher so eo) or nil -- what -o prints next.
(def %grep-better?
  (fn (_ p best)
    (match
      ((null? best) #t)
      ((< (first p) (first best)) #t)
      ((> (first p) (first best)) #f)
      (#t (> (first (rest p)) (first (rest best)))))))

(def grep-hit-at
  (fn (self ms line lline word xline at best)
    (if (null? ms) best
      (%grep-hit-at-one self ms line lline word xline at best))))

(def %grep-hit-at-one
  (fn (_ again ms line lline word xline at best)
    (def p (%grep-match-at (first ms) line lline word xline at))
    (again (rest ms) line lline word xline at
      (if (null? p) best
        (if (%grep-better? p (if (null? best) () (rest best)))
          (pair (first ms) p)
          best)))))

(provide grep/bre grep-xlate-bre grep-xlate grep-b->s grep-compile-one
  grep-lower grep-hit grep-hit-at)
