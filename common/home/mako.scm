;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common home mako)
  #:use-module (guix gexp)
  #:use-module (gnu home services)
  #:use-module (gnu packages gnome)
  #:use-module (sagittarius locked wm)
  #:use-module (common home helpers)
  #:use-module (common home wm)
  #:use-module (common machines)
  #:use-module (common themes)
  #:export (mako-services))

(define (mako-config theme)
  (plain-file "mako-config"
              (string-concatenate (map (lambda (entry)
                                         (string-append (car entry) "="
                                                        (cdr entry) "\n"))
                                       (cons '("border-radius" . "12")
                                             (color-entries theme
                                                            '(("background-color" . bg_2)
                                                              ("text-color" . fg_0)
                                                              ("border-color" . bg_1)
                                                              ("progress-color" . cyan))))))))

(define (mako-services machine)
  (list (home-packages mako-locked libnotify)
        (simple-service 'mako-config home-xdg-configuration-files-service-type
                        `(("mako/config" ,(mako-config (machine-theme machine)))))
        (wm-extensions machine
                       'mako-wm
                       (wm-autostart (file-append mako-locked "/bin/mako"))
                       (wm-layer-rule "^notifications$"
                                      #:hide-from-screencast? #t))))
