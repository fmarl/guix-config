;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common home bemenu)
  #:use-module (guix gexp)
  #:use-module (sagittarius locked gnupg)
  #:use-module (gnu packages xdisorg)
  #:use-module (common home colors)
  #:use-module (common home helpers)
  #:export (bemenu-run
            bemenu-askpass
            pinentry-bemenu*))

(define bemenu-settings
  `(("tb" . ,(color 'bg_1))
    ("tf" . ,(color 'br_blue))
    ("fb" . ,(color 'bg_1))
    ("ff" . ,(color 'fg_0))
    ("cb" . ,(color 'bg_1))
    ("cf" . ,(color 'cursor))
    ("nb" . ,(color 'bg_0))
    ("nf" . ,(color 'fg_1))
    ("ab" . ,(color 'bg_0))
    ("af" . ,(color 'fg_1))
    ("hb" . ,(color 'bg_region))
    ("hf" . ,(color 'fg_0))
    ("sb" . ,(color 'bg_accent))
    ("sf" . ,(color 'fg_0))
    ("fbb" . ,(color 'bg_0))
    ("fbf" . ,(color 'yellow))
    ("scb" . ,(color 'bg_1))
    ("scf" . ,(color 'bg_active))
    ("bdr" . ,(color 'border))
    ("fn" . "Aporetic Sans Mono 12")
    ("line-height" . "26")
    ("prompt" . "λ ~>")))

(define bemenu-arguments
  (string-concatenate
   (map (lambda (setting)
          (string-append " --" (car setting) " '" (cdr setting) "'"))
        bemenu-settings)))

(define bemenu-run
  (shell-script "bemenu-run"
                "exec " bemenu "/bin/bemenu-run" bemenu-arguments " \"$@\"\n"))

;; pinentry-bemenu takes its options only from BEMENU_OPTS
(define pinentry-bemenu*
  (shell-script "pinentry-bemenu"
                "export BEMENU_OPTS=\"" bemenu-arguments "\"\nexec "
                pinentry-bemenu-locked "/bin/pinentry-bemenu \"$@\"\n"))

(define bemenu-askpass
  (shell-script "bemenu-askpass"
                "exec " bemenu "/bin/bemenu" bemenu-arguments
                " --password indicator --prompt \"$1\" </dev/null\n"))
