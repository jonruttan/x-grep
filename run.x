; # x-grep -- POSIX grep on x-lang
;
; ## run.x -- the entry point
;
; @description A POSIX grep: BRE by default, -E for ERE, -F for fixed
;   strings, on lib/x/type/regex.x.  The second tool of the self-hosting
;   arc, after x-awk.
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; Usage:
;   x -l grep -- [-EFcilnqsvwx] [-e pat]... [-f patfile]... [pat] [file]...
;
; This file contains no path literals: x.sh boots the dialect, arms the bundle
; root, and cats this file. With operands, grep-main runs and exits with grep's
; own status (0 match, 1 none, 2 trouble), so the launcher never starts a REPL
; under a batch run. With no operands it is the x REPL with the core loaded:
; (grep-run ARGV INPUT) at a prompt.
(import grep/base)

(set! %lang-name "GREP")
(set! %lang-version grep-version)
(set! %repl-prompt "grep> ")
(set! %repl-print %grep-repl-print)

(unless (null? (grep-argv args))
  (grep-main args))
