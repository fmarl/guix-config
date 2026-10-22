;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common home bemenu)
  #:use-module (gnu packages xdisorg)
  #:use-module (sagittarius locked gnupg)
  #:use-module (common home helpers)
  #:use-module (common home theme)
  #:use-module (common home wm)
  #:use-module (common machines)
  #:use-module (common themes)
  #:use-module (ice-9 match)
  #:export (bemenu-askpass
            bemenu-pinentry
            bemenu-services))

(define (bemenu-settings theme)
  (append (color-entries theme
                         '(("tb" . bg_0)
                           ("tf" . br_blue)
                           ("fb" . bg_0)
                           ("ff" . fg_0)
                           ("cb" . bg_0)
                           ("cf" . cursor)
                           ("nb" . bg_0)
                           ("nf" . dim_0)
                           ("ab" . bg_0)
                           ("af" . dim_0)
                           ("hb" . bg_0)
                           ("hf" . br_blue)
                           ("sb" . bg_accent)
                           ("sf" . fg_0)
                           ("fbb" . bg_0)
                           ("fbf" . yellow)))
          `(("bdr" . ,(hairline-color theme))
            ("border" . 1)
            ("fn" . ,(string-append %monospace-font " 10"))
            ("line-height" . ,%bar-height)
            ("hp" . ,%spacing))))

(define %bemenu-run-settings
  '(("ignorecase" . #t)
    ("single-instance" . #t)
    ("counter" . "always")
    ("prefix" . "›")
    ("prompt" . "λ")))

(define (bemenu-arguments settings)
  (string-concatenate
   (map (match-lambda
          ((name . #t)
           (string-append " --" name))
          ((name . value)
           (string-append " --" name " "
                          (shell-quote (format #f "~a" value)))))
        settings)))

(define (bemenu-run theme)
  (shell-script "bemenu-run"
                "exec " bemenu "/bin/bemenu-run"
                (bemenu-arguments (append (bemenu-settings theme)
                                          %bemenu-run-settings))
                " \"$@\"\n"))

(define %pinentry-options
  '("tb" "tf" "fb" "ff" "cb" "cf" "nb" "nf" "ab" "af" "hb" "hf" "sb" "sf"
    "fbb" "fbf" "fn" "line-height"))

;; pinentry-bemenu takes its options only from BEMENU_OPTS and stops reading
;; them at the first one it does not know
(define (bemenu-pinentry theme)
  (shell-script "pinentry-bemenu"
                "export BEMENU_OPTS="
                (shell-quote
                 (bemenu-arguments
                  (filter (match-lambda
                            ((name . _)
                             (member name %pinentry-options)))
                          (bemenu-settings theme))))
                "\nexec " pinentry-bemenu-locked
                "/bin/pinentry-bemenu \"$@\"\n"))

(define (bemenu-askpass theme)
  (shell-script "bemenu-askpass"
                "exec " bemenu "/bin/bemenu"
                (bemenu-arguments (bemenu-settings theme))
                " --password indicator --prompt \"$1\" </dev/null\n"))

(define (bemenu-services machine)
  (list (wm-extensions machine 'bemenu-wm
                       (wm-bind "Mod+P"
                                (list (bemenu-run (machine-theme machine)))
                                #:title "Run bemenu"))))
