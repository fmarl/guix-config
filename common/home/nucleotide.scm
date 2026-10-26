;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common home nucleotide)
  #:use-module (guix gexp)
  #:use-module (gnu home services)
  #:use-module (gnu packages freedesktop)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages xorg)
  #:use-module (gnu services)
  #:use-module (sagittarius home services wm)
  #:use-module (common files)
  #:use-module (common home helpers)
  #:use-module (common themes)
  #:export (nucleotide-services))

(define (nucleotide-settings theme)
  `((setf *border-focused* ,(color theme 'br_blue))
    (setf *border-unfocused* ,(color theme 'border))
    (load (uiop:xdg-config-home "nucleotide" "config.lisp"))))

(define action-binds
  (list (nucleotide-bind "Mod+Shift+C" 'close-window)
        (nucleotide-bind "Mod+Shift+F" 'toggle-fullscreen)
        (nucleotide-bind "Mod+Shift+E" 'exit-session)
        (nucleotide-bind "Ctrl+Alt+Delete" 'exit-session)))

(define portals-conf
  (plain-file "river-portals.conf" "\
[preferred]
default=gtk;
org.freedesktop.impl.portal.ScreenCast=wlr;
org.freedesktop.impl.portal.Screenshot=wlr;
"))

(define dbus-update-activation-environment
  (file-append dbus "/bin/dbus-update-activation-environment"))

(define (nucleotide-services theme)
  (list (home-packages xdg-desktop-portal-wlr xorg-server-xwayland)
        (simple-service 'nucleotide-files
                        home-xdg-configuration-files-service-type
                        `(("xdg-desktop-portal/river-portals.conf"
                           ,portals-conf)
                          ("nucleotide/config.lisp"
                           ,(config-file "dotfiles/.config/nucleotide/config.lisp"))))
        (service home-nucleotide-service-type
                 (home-nucleotide-configuration
                   (settings (nucleotide-settings theme))
                   (entries
                    (cons (nucleotide-autostart
                           dbus-update-activation-environment
                           "WAYLAND_DISPLAY" "XDG_CURRENT_DESKTOP")
                          action-binds))))))
