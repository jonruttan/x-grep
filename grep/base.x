; # x-grep -- POSIX grep on x-lang
;
; ## grep/base.x -- the tool, assembled
;
; @author [Jon Ruttan](jonruttan@gmail.com)
; @copyright 2026 Jon Ruttan
; @license MIT No Attribution (MIT-0)
;
; No path literals and no dialect boot here: run.x owns both, and the
; spec harness stands in for run.x under the suite.  Nothing under
; grep/ includes a platform module (x-lang#515).



(module grep/base)
(import grep/bre grep-xlate-bre)
(import grep/core grep-run grep-parse-cli)
(import grep/cli grep-argv grep-main)

(def grep-version "0.1.0")

; The default printer, quiet about nil -- the result of a grep run is
; its status, which belongs in $?, not on stdout.
(def grep-repl-print
  (fn (_ result)
    (unless (null? result) (write result))
    (newline)))

; The tool's surface, assembled: the version and the printer are this
; module's, the rest re-exported from the modules that define them.
(provide grep/base grep-version grep-repl-print grep-xlate-bre grep-run
  grep-parse-cli grep-argv grep-main)
