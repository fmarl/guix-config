;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common home theme)
  #:use-module (guix gexp)
  #:use-module (gnu home services)
  #:use-module (gnu packages base)
  #:use-module (gnu packages fonts)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages gnome)
  #:use-module (gnu packages gnome-xyz)
  #:use-module (nongnu packages fonts)
  #:use-module (common home helpers)
  #:use-module (common machines)
  #:use-module (common themes)
  #:export (theme-services
            %bar-height
            %cursor-theme
            %cursor-size
            %monospace-font
            %corner-radius
            %small-corner-radius
            %small-spacing
            %spacing
            %large-spacing
            hairline-color
            %popup-alpha
            %sans-font))

(define %bar-height 28)

(define %cursor-theme "Bibata-Modern-Classic")
(define %cursor-size 24)

(define %monospace-font "Aporetic Sans Mono")
(define %sans-font "Inter")

(define %corner-radius 10)
(define %small-corner-radius 6)

(define %small-spacing 4)
(define %spacing 8)
(define %large-spacing 12)

(define %popup-alpha 0.95)

(define* (hairline-color theme #:optional (format-color color-hex-alpha))
  "Return the color of THEME for thin borders, as FORMAT-COLOR formats it."
  (format-color theme 'fg_0 0.1))

(define (gtk-theme-name theme)
  (if (theme-dark? theme) "adw-gtk3-dark" "adw-gtk3"))

(define (icon-theme-name theme)
  (if (theme-dark? theme) "Papirus-Dark" "Papirus"))

(define (gtk-settings theme)
  (ini-file "settings.ini"
            `(("Settings"
               ("gtk-theme-name" . ,(gtk-theme-name theme))
               ("gtk-icon-theme-name" . ,(icon-theme-name theme))
               ("gtk-cursor-theme-name" . ,%cursor-theme)
               ("gtk-cursor-theme-size" . ,%cursor-size)
               ("gtk-font-name" . ,(string-append %sans-font " 11"))
               ("gtk-application-prefer-dark-theme" . ,(theme-dark? theme))))))

(define (gtk-css theme)
  (define hairline
    (hairline-color theme color-rgba))

  (plain-file
   "gtk.css"
   (string-concatenate
    (map (lambda (entry)
           (string-append "@define-color " (car entry) " " (cdr entry) ";\n"))
         (append
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
                           ("headerbar_border_color" . border)
                           ("sidebar_bg_color" . bg_1)
                           ("sidebar_fg_color" . fg_0)
                           ("sidebar_backdrop_color" . bg_0)
                           ("secondary_sidebar_bg_color" . bg_1)
                           ("secondary_sidebar_fg_color" . fg_0)
                           ("secondary_sidebar_backdrop_color" . bg_0)
                           ("card_bg_color" . bg_1)
                           ("card_fg_color" . fg_0)
                           ("dialog_bg_color" . bg_1)
                           ("dialog_fg_color" . fg_0)
                           ("popover_bg_color" . bg_popup)
                           ("popover_fg_color" . fg_0)
                           ("thumbnail_bg_color" . bg_1)
                           ("thumbnail_fg_color" . fg_0)
                           ("scrollbar_outline_color" . bg_0)
                           ("destructive_color" . red)
                           ("destructive_bg_color" . red)
                           ("destructive_fg_color" . bg_0)
                           ("success_color" . green)
                           ("success_bg_color" . green)
                           ("success_fg_color" . bg_0)
                           ("warning_color" . yellow)
                           ("warning_bg_color" . yellow)
                           ("warning_fg_color" . bg_0)
                           ("error_color" . red)
                           ("error_bg_color" . red)
                           ("error_fg_color" . bg_0)))
          `(("sidebar_border_color" . ,hairline)
            ("secondary_sidebar_border_color" . ,hairline)))))))

(define (interface-settings-activation theme)
  #~(for-each
     (lambda (setting)
       (apply system* #$(file-append coreutils "/bin/env")
              "GSETTINGS_BACKEND=keyfile"
              (string-append "GSETTINGS_SCHEMA_DIR="
                             #$(file-append gsettings-desktop-schemas
                                            "/share/glib-2.0/schemas"))
              (string-append #$glib:bin "/bin/gsettings")
              "set" "org.gnome.desktop.interface" setting))
     '(("color-scheme" #$(if (theme-dark? theme) "prefer-dark" "default"))
       ("gtk-theme" #$(gtk-theme-name theme))
       ("icon-theme" #$(icon-theme-name theme)))))

(define (theme-name-activation theme)
  #~(call-with-output-file
        (string-append (or (getenv "XDG_CONFIG_HOME")
                           (string-append (getenv "HOME") "/.config"))
                       "/theme")
      (lambda (port)
        (display #$(symbol->string (theme-name theme)) port))))

(define (theme-services machine)
  (define theme
    (machine-theme machine))

  (list (home-packages adw-gtk3-theme
                       papirus-icon-theme
                       adwaita-icon-theme
                       bibata-cursor-theme
                       font-awesome-nonfree
                       (list font-inter "ttf"))
        (simple-service 'gtk-theme home-xdg-configuration-files-service-type
                        `(("gtk-3.0/settings.ini" ,(gtk-settings theme))
                          ("gtk-3.0/gtk.css" ,(gtk-css theme))
                          ("gtk-4.0/settings.ini" ,(gtk-settings theme))
                          ("gtk-4.0/gtk.css" ,(gtk-css theme))))
        (simple-service 'interface-settings home-activation-service-type
                        (interface-settings-activation theme))
        (simple-service 'theme-name home-activation-service-type
                        (theme-name-activation theme))
        (simple-service 'cursor-theme home-environment-variables-service-type
                        `(("XCURSOR_THEME" . ,%cursor-theme)
                          ("XCURSOR_SIZE" . ,(number->string %cursor-size))))))
