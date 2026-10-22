;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common home swayidle)
  #:use-module (guix gexp)
  #:use-module (gnu home services)
  #:use-module (gnu packages window-management)
  #:use-module (common home helpers)
  #:use-module (common home theme)
  #:use-module (common home wm)
  #:use-module (common machines)
  #:use-module (common themes)
  #:use-module (ice-9 match)
  #:export (swayidle-services))

(define (swaylock-config theme)
  (key-value-file
   "swaylock-config"
   `(("daemonize" . #t)
     ("line-uses-inside" . #t)
     ("font" . ,%sans-font)
     ,@(color-entries theme
                      '(("color" . bg_0)
                        ("inside-color" . bg_0)
                        ("inside-clear-color" . bg_0)
                        ("inside-ver-color" . bg_0)
                        ("inside-wrong-color" . bg_0)
                        ("ring-color" . bg_region)
                        ("ring-clear-color" . bg_region)
                        ("ring-ver-color" . bg_accent)
                        ("ring-wrong-color" . red)
                        ("key-hl-color" . bg_accent)
                        ("bs-hl-color" . red)
                        ("text-color" . fg_0)
                        ("text-clear-color" . fg_0)
                        ("text-ver-color" . fg_0)
                        ("text-wrong-color" . red))))
   #:separator "="))

(define lock
  (file-append swaylock "/bin/swaylock"))

(define (monitors-off wm)
  (match wm
    ('niri
     (list "'" niri "/bin/niri msg action power-off-monitors'" "\n"))
    ('nucleotide
     (let ((wlopm (file-append wlopm "/bin/wlopm")))
       (list "'" wlopm " --off \\*' resume '" wlopm " --on \\*'\n")))))

(define (swayidle-config wm)
  (apply mixed-text-file "swayidle-config"
         "timeout 600 '" lock "'\n"
         "timeout 900 " (monitors-off wm)))

(define (swayidle-services machine)
  (list (home-packages swayidle swaylock)
        (simple-service 'swayidle-config
                        home-xdg-configuration-files-service-type
                        `(("swayidle/config"
                           ,(swayidle-config (machine-wm machine)))
                          ("swaylock/config"
                           ,(swaylock-config (machine-theme machine)))))
        (wm-extensions machine 'swayidle
                       (wm-autostart (file-append swayidle "/bin/swayidle")
                                     "-w")
                       (wm-bind "Super+Alt+L" (list lock)
                                #:title "Lock the screen"))))
