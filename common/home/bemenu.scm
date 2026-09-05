;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common home bemenu)
  #:use-module (guix gexp)
  #:use-module (sagittarius locked gnupg)
  #:use-module (gnu packages xdisorg)
  #:use-module (common home helpers)
  #:use-module (common themes)
  #:export (bemenu-run bemenu-askpass pinentry-bemenu*))

(define (bemenu-settings theme)
  `(("tb" unquote
     (color theme
            'bg_1))
    ("tf" unquote
     (color theme
            'br_blue))
    ("fb" unquote
     (color theme
            'bg_1))
    ("ff" unquote
     (color theme
            'fg_0))
    ("cb" unquote
     (color theme
            'bg_1))
    ("cf" unquote
     (color theme
            'cursor))
    ("nb" unquote
     (color theme
            'bg_0))
    ("nf" unquote
     (color theme
            'fg_1))
    ("ab" unquote
     (color theme
            'bg_0))
    ("af" unquote
     (color theme
            'fg_1))
    ("hb" unquote
     (color theme
            'bg_region))
    ("hf" unquote
     (color theme
            'fg_0))
    ("sb" unquote
     (color theme
            'bg_accent))
    ("sf" unquote
     (color theme
            'fg_0))
    ("fbb" unquote
     (color theme
            'bg_0))
    ("fbf" unquote
     (color theme
            'yellow))
    ("scb" unquote
     (color theme
            'bg_1))
    ("scf" unquote
     (color theme
            'bg_active))
    ("bdr" unquote
     (color theme
            'border))
    ("fn" . "Aporetic Sans Mono 12")
    ("line-height" . "26")
    ("prompt" . "λ ~>")))

(define (bemenu-arguments theme)
  (string-concatenate (map (lambda (setting)
                             (string-append " --"
                                            (car setting) " '"
                                            (cdr setting) "'"))
                           (bemenu-settings theme))))

(define (bemenu-run theme)
  (shell-script "bemenu-run"
                "exec "
                bemenu
                "/bin/bemenu-run"
                (bemenu-arguments theme)
                " \"$@\"\n"))

;; pinentry-bemenu takes its options only from BEMENU_OPTS
(define (pinentry-bemenu* theme)
  (shell-script "pinentry-bemenu"
                "export BEMENU_OPTS=\""
                (bemenu-arguments theme)
                "\"\nexec "
                pinentry-bemenu-locked
                "/bin/pinentry-bemenu \"$@\"\n"))

(define (bemenu-askpass theme)
  (shell-script "bemenu-askpass"
                "exec "
                bemenu
                "/bin/bemenu"
                (bemenu-arguments theme)
                " --password indicator --prompt \"$1\" </dev/null
"))
