;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common home theme)
  #:use-module (guix gexp)
  #:use-module (gnu home services)
  #:use-module (gnu packages gnome)
  #:use-module (gnu packages gnome-xyz)
  #:use-module (nongnu packages fonts)
  #:use-module (common home helpers)
  #:use-module (common machines)
  #:use-module (common themes)
  #:export (theme-services %cursor-theme %cursor-size %monospace-font))

(define %cursor-theme
  "Bibata-Modern-Classic")

(define %cursor-size
  24)

(define %monospace-font
  "Aporetic Sans Mono")

(define (gtk-settings theme)
  (define dark?
    (theme-dark? theme))

  (ini-file "settings.ini"
            `(("Settings" ("gtk-theme-name" unquote
                           (if dark? "adw-gtk3-dark" "adw-gtk3"))
               ("gtk-icon-theme-name" unquote
                (if dark? "Papirus-Dark" "Papirus"))
               ("gtk-cursor-theme-name" unquote %cursor-theme)
               ("gtk-cursor-theme-size" unquote %cursor-size)
               ("gtk-font-name" . "Aporetic Sans 11")
               ("gtk-application-prefer-dark-theme" unquote dark?)))))

(define (gtk-css theme)
  (plain-file "gtk.css"
              (string-concatenate (map (lambda (entry)
                                         (string-append "@define-color "
                                                        (car entry) " "
                                                        (cdr entry) ";\n"))
                                       (color-entries theme
                                                      '(("accent_color" . br_blue)
                                                        ("accent_bg_color" . bg_accent)
                                                        ("accent_fg_color" . fg_0)
                                                        ("window_bg_color" . bg_0)
                                                        ("window_fg_color" . fg_0)
                                                        ("view_bg_color" . bg_0)
                                                        ("view_fg_color" . fg_0)
                                                        ("headerbar_bg_color" . bg_1)
                                                        ("headerbar_fg_color" . fg_0)
                                                        ("headerbar_backdrop_color" . bg_0)
                                                        ("sidebar_bg_color" . bg_1)
                                                        ("sidebar_fg_color" . fg_0)
                                                        ("card_bg_color" . bg_1)
                                                        ("card_fg_color" . fg_0)
                                                        ("dialog_bg_color" . bg_1)
                                                        ("dialog_fg_color" . fg_0)
                                                        ("popover_bg_color" . bg_popup)
                                                        ("popover_fg_color" . fg_0)
                                                        ("destructive_color" . red)
                                                        ("success_color" . green)
                                                        ("warning_color" . yellow)
                                                        ("error_color" . red)))))))

(define (theme-services machine)
  (define theme
    (machine-theme machine))

  (list (home-packages adw-gtk3-theme papirus-icon-theme adwaita-icon-theme
                       bibata-cursor-theme font-awesome-nonfree)
        (simple-service 'gtk-theme home-xdg-configuration-files-service-type
                        `(("gtk-3.0/settings.ini" ,(gtk-settings theme))
                          ("gtk-3.0/gtk.css" ,(gtk-css theme))
                          ("gtk-4.0/settings.ini" ,(gtk-settings theme))
                          ("gtk-4.0/gtk.css" ,(gtk-css theme))))
        (simple-service 'cursor-theme home-environment-variables-service-type
                        `(("XCURSOR_THEME" unquote %cursor-theme)
                          ("XCURSOR_SIZE" unquote
                           (number->string %cursor-size))))))
