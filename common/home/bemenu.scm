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
  #:export (bemenu-askpass bemenu-pinentry bemenu-services))

(define (bemenu-settings theme)
  (append (color-entries theme
                         '(("tb" . bg_1) ("tf" . br_blue)
                           ("fb" . bg_1)
                           ("ff" . fg_0)
                           ("cb" . bg_1)
                           ("cf" . cursor)
                           ("nb" . bg_0)
                           ("nf" . fg_1)
                           ("ab" . bg_0)
                           ("af" . fg_1)
                           ("hb" . bg_region)
                           ("hf" . fg_0)
                           ("sb" . bg_accent)
                           ("sf" . fg_0)
                           ("fbb" . bg_0)
                           ("fbf" . yellow)
                           ("scb" . bg_1)
                           ("scf" . bg_active)
                           ("bdr" . border)))
          `(("fn" unquote
             (string-append %monospace-font " 12"))
            ("line-height" . "26")
            ("prompt" . "λ ~>"))))

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
(define (bemenu-pinentry theme)
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

(define (bemenu-services machine)
  (list (wm-extensions machine
                       'bemenu-wm
                       (wm-bind "Mod+P"
                                (list (bemenu-run (machine-theme machine)))
                                #:title "Run bemenu"))))
