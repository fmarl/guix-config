;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common home mako)
  #:use-module (guix gexp)
  #:use-module (gnu home services)
  #:use-module (gnu packages gnome)
  #:use-module (sagittarius locked wm)
  #:use-module (common home helpers)
  #:use-module (common home theme)
  #:use-module (common home wm)
  #:use-module (common machines)
  #:use-module (common themes)
  #:export (mako-services))

(define (mako-config theme)
  (key-value-file
   "mako-config"
   `(("font" . ,(string-append %sans-font " 11"))
     ("border-radius" . ,%corner-radius)
     ("border-size" . 1)
     ("padding" . ,%large-spacing)
     ("margin" . ,%large-spacing)
     ("background-color" . ,(color-hex-alpha theme 'bg_popup %popup-alpha))
     ("border-color" . ,(hairline-color theme))
     ,@(color-entries theme
                      '(("text-color" . fg_0)
                        ("progress-color" . bg_accent)))
     ("[urgency=critical]" . #t)
     ("border-size" . 2)
     ("border-color" . ,(color theme 'red)))
   #:separator "="))

(define (mako-services machine)
  (list (home-packages mako-locked libnotify)
        (simple-service 'mako-config home-xdg-configuration-files-service-type
                        `(("mako/config"
                           ,(mako-config (machine-theme machine)))))
        (wm-extensions machine 'mako-wm
                       (wm-autostart (file-append mako-locked "/bin/mako"))
                       (wm-layer-rule "^notifications$"
                                      #:hide-from-screencast? #t))))
