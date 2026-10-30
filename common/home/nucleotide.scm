;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common home nucleotide)
  #:use-module (guix gexp)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:use-module (gnu home services)
  #:use-module (gnu packages freedesktop)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages image)
  #:use-module (gnu packages window-management)
  #:use-module (gnu packages xdisorg)
  #:use-module (gnu packages xorg)
  #:use-module (gnu services)
  #:use-module (sagittarius home services wm)
  #:use-module (common files)
  #:use-module (common home helpers)
  #:use-module (common home theme)
  #:use-module (common machines)
  #:use-module (common themes)
  #:export (nucleotide-services))

(define (nucleotide-settings theme)
  `((setf *border-focused* ,(color theme 'br_blue))
    (setf *border-unfocused* ,(color theme 'border))
    (setf *cursor-theme* '(,%cursor-theme ,%cursor-size))
    (setf *libinput-settings* '(#:tap #t #:click-method #:button-areas))
    (setf *which-key-delay* 500)
    (load (uiop:xdg-config-home "nucleotide" "config.lisp"))))

(define screenshot
  (shell-script-file "screenshot"
                     (list (local-file "files/screenshot.sh"))
                     #:variables
                     `(("grim" . ,(file-append grim "/bin/grim"))
                       ("slurp" . ,(file-append slurp "/bin/slurp"))
                       ("wl_copy" . ,(file-append wl-clipboard "/bin/wl-copy")))))

(define action-binds
  (list (nucleotide-bind "Mod+Shift+C" 'close-window #:description "close")
        (nucleotide-bind "Mod+Shift+F" 'toggle-fullscreen
                         #:description "fullscreen")
        (nucleotide-bind "Mod+Shift+E" 'exit-session #:description "quit")
        (nucleotide-bind "Ctrl+Alt+Delete" 'exit-session #:description "quit")))

(define screenshot-binds
  (list (nucleotide-bind "Print" (nucleotide-spawn screenshot)
                         #:description "screenshot")
        (nucleotide-bind "Ctrl+Print" (nucleotide-spawn screenshot "-o")
                         #:description "screenshot monitor")
        (nucleotide-bind "Mod+S" (nucleotide-spawn screenshot)
                         #:description "screenshot")
        (nucleotide-bind "Mod+Ctrl+S" (nucleotide-spawn screenshot "-o")
                         #:description "screenshot monitor")))

(define portals-conf
  (plain-file "river-portals.conf" "\
[preferred]
default=gtk;
org.freedesktop.impl.portal.ScreenCast=wlr;
org.freedesktop.impl.portal.Screenshot=wlr;
"))

(define dbus-update-activation-environment
  (file-append dbus "/bin/dbus-update-activation-environment"))

(define (backdrop theme)
  (nucleotide-autostart (file-append swaybg "/bin/swaybg")
                        "-c" (color theme 'bg_2)))

(define (output-positions machine)
  (match (machine-outputs machine)
    (() '())
    (outputs
     (list (apply nucleotide-autostart
                  (file-append wlr-randr "/bin/wlr-randr")
                  (append-map (match-lambda
                                ((name x y)
                                 (list "--output" name
                                       "--pos" (format #f "~a,~a" x y))))
                              outputs))))))

(define (nucleotide-services machine)
  (define theme
    (machine-theme machine))

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
                    (append (list (nucleotide-autostart
                                   dbus-update-activation-environment
                                   "WAYLAND_DISPLAY" "XDG_CURRENT_DESKTOP")
                                  (backdrop theme))
                            (output-positions machine)
                            action-binds
                            screenshot-binds))))))
