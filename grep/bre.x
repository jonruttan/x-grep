; # x-grep -- POSIX grep on x-lang
;
; ## grep/bre.x -- patterns to matchers
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; POSIX grep speaks BRE by default, where ( ) { } + ? | are literal and \( \)
; \{ \} are the operators; lib/x/type/regex.x speaks an ERE-like dialect. So
; BRE translates by swapping the escapes: bare grouping characters gain a
; backslash, the backslashed operators lose theirs. -E passes through.
; Case-insensitivity is compiled into the pattern -- a literal letter becomes
; its two-case class, a class entry gains its swapped twin -- so no engine flag
; is needed; -w wraps the pattern in \b( )\b, the engine's word anchors.
;
; Refused loudly, because a loud error beats a silent wrong match:
; back-references \1-\9 (the engine cannot) and [:named:] classes (pending
; upstream).

; case-swap a letter byte, else nil
(def %grep-swap
  (fn (_ b)
    (if (if (>= b 97) (<= b 122) #f) (- b 32)
      (if (if (>= b 65) (<= b 90) #f) (+ b 32) ()))))

(def %grep-b->s
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

; Copy a [...] class, expanding case when ci: each letter (or letter
; range) also emits its swapped twin.  Answers (pieces . next-i),
; pieces reversed.  Raises on [:named:].
(def %grep-xl-class
  (fn (_ pat end i0 ci acc0)
    (def go
      (fn (self i acc first?)
        (if (>= i end)
          (Err raise (lit grep) "grep: unterminated [ class" pat)
          (let ((b (byte-at pat i)))
            (if (if (= b 93) (not first?) #f)             ; closing ]
              (pair (pair "]" acc) (+ i 1))
              (if (if (= b 91)                             ; [: ?
                    (if (< (+ i 1) end) (= (byte-at pat (+ i 1)) 58) #f)
                    #f)
                (Err raise (lit grep)
                  "grep: [:named:] classes are not supported yet" pat)
                ; a-b range?
                (if (if (< (+ i 2) end)
                      (if (= (byte-at pat (+ i 1)) 45)     ; -
                        (not (= (byte-at pat (+ i 2)) 93))
                        #f)
                      #f)
                  (let ((lo b))
                    (def hi (byte-at pat (+ i 2)))
                    (def piece
                      (string-append (%grep-b->s lo) "-" (%grep-b->s hi)))
                    (def swl (%grep-swap lo))
                    (def swh (%grep-swap hi))
                    (self (+ i 3)
                      (if (if ci (not (null? swl)) #f)
                        (pair (string-append (%grep-b->s swl) "-"
                                (%grep-b->s (if (null? swh) hi swh)))
                          (pair piece acc))
                        (pair piece acc))
                      #f))
                  (let ((sw (%grep-swap b)))
                    (self (+ i 1)
                      (if (if ci (not (null? sw)) #f)
                        (pair (%grep-b->s sw) (pair (%grep-b->s b) acc))
                        (pair (%grep-b->s b) acc))
                      #f)))))))))
    ; leading ^ and a first-position ] are literal parts of the class
    (def i1 (if (if (< i0 end) (= (byte-at pat i0) 94) #f) (+ i0 1) i0))
    (def acc1 (if (= i1 i0) (pair "[" acc0) (pair "[^" acc0)))
    (go i1 acc1 #t)))

; One literal byte, case-expanded when ci and a letter.
(def %grep-xl-lit
  (fn (_ b ci acc)
    (let ((sw (if ci (%grep-swap b) ())))
      (if (null? sw)
        (pair (%grep-b->s b) acc)
        (pair (string-append "[" (%grep-b->s b) (%grep-b->s sw) "]") acc)))))

; The translator: BRE or ERE text to the engine's dialect.
(def %grep-xlate
  (fn (_ pat bre? ci)
    (def end (byte-len pat))
    (def go
      (fn (self i acc)
        (if (>= i end) (string-concat (reverse acc))
          (let ((b (byte-at pat i)))
            (if (= b 91)                                   ; [
              (let ((r (%grep-xl-class pat end (+ i 1) ci acc)))
                (self (rest r) (first r)))
              (if (= b 92)                                 ; backslash
                (if (>= (+ i 1) end)
                  (self (+ i 1) (pair "\\\\" acc))
                  (let ((e (byte-at pat (+ i 1))))
                    (if (if (>= e 49) (<= e 57) #f)        ; \1-\9
                      (Err raise (lit grep)
                        "grep: back-references are not supported" pat)
                      (if (if bre?
                            (match ((= e 40) #t) ((= e 41) #t)
                                   ((= e 123) #t) ((= e 125) #t)
                                   (#t #f))
                            #f)
                        ; BRE \( \) \{ \} are the OPERATORS: unescape
                        (self (+ i 2) (pair (%grep-b->s e) acc))
                        (if (if ci
                              (if (null? (%grep-swap e)) #f
                                (not (%grep-esc-special? e)))
                              #f)
                          ; escaped plain letter under -i: two-case class
                          (self (+ i 2) (%grep-xl-lit e ci acc))
                          (self (+ i 2)
                            (pair (string-append "\\" (%grep-b->s e))
                              acc)))))))
                (if (if bre?
                      (match ((= b 40) #t) ((= b 41) #t)
                             ((= b 123) #t) ((= b 125) #t)
                             ((= b 43) #t)  ((= b 63) #t)
                             ((= b 124) #t) (#t #f))
                      #f)
                  ; BRE bare ( ) { } + ? | are LITERAL: escape for the engine
                  (self (+ i 1)
                    (pair (string-append "\\" (%grep-b->s b)) acc))
                  (if (if (null? (%grep-swap b)) #t (not ci))
                    (self (+ i 1) (pair (%grep-b->s b) acc))
                    (self (+ i 1) (%grep-xl-lit b ci acc))))))))))
    (go 0 ())))

; The pure translation door the specs exercise.
(def grep-xlate-bre
  (fn (_ pat) (%grep-xlate pat #t #f)))

; lowercase a whole string, bytewise (-F -i)
(def %grep-lower
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

; One pattern to a matcher: (LABEL DATA), where LABEL is rx (search),
; rx-full (-x), fix (substring), or fix-x (equality); fixed DATA is
; pre-lowered under -i and the line lowers at match time.
(def %grep-compile-one
  (fn (_ pat label ci word xline)
    (if (eq? label (lit fixed))
      (list (if xline (lit fix-x) (lit fix))
        (if ci (%grep-lower pat) pat))
      (let ((xl (%grep-xlate pat (eq? label (lit bre)) ci)))
        (def wrapped
          (if word (string-append "\\b(" xl ")\\b") xl))
        (list (if xline (lit rx-full) (lit rx))
          (regex-compile wrapped))))))

; substring search, bytes (the x-awk pattern)
(def %grep-find?
  (fn (_ s t)
    (def ls (byte-len s))
    (def lt (byte-len t))
    (def hit?
      (fn (self i j)
        (if (>= j lt) #t
          (if (= (byte-at s (+ i j)) (byte-at t j))
            (self i (+ j 1))
            #f))))
    (def go
      (fn (self i)
        (if (> (+ i lt) ls) #f
          (if (hit? i 0) #t (self (+ i 1))))))
    (go 0)))

; Does LINE satisfy MATCHER?  ci says whether fixed matchers see the
; lowered line.
(def %grep-hit?
  (fn (_ m line lline)
    (let ((label (first m)))
      (if (eq? label (lit rx))
        (not (null? (regex-search line (first (rest m)))))
        (if (eq? label (lit rx-full))
          (regex-match line (first (rest m)))
          (if (eq? label (lit fix))
            (%grep-find? (if (null? lline) line lline) (first (rest m)))
            (string=? (if (null? lline) line lline) (first (rest m)))))))))

(def %grep-any-hit?
  (fn (self ms line lline)
    (if (null? ms) #f
      (if (%grep-hit? (first ms) line lline) #t
        (self (rest ms) line lline)))))
