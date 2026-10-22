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
  #:use-module (common home helpers)
  #:use-module (common themes)
  #:use-module (ice-9 match)
  #:export (nucleotide-services))

(define (rgb theme name)
  (let ((hex (color theme name)))
    (string-join (map (lambda (start)
                        (number->string
                         (string->number (substring hex start (+ start 2))
                                         16)))
                      '(1 3 5))
                 " ")))

(define (nucleotide-settings theme)
  (string-append "(defparameter *focused-border-rgba* '("
                 (rgb theme 'br_blue)
                 " 255))
(defparameter *unfocused-border-rgba* '("
                 (rgb theme 'border)
                 " 255))

(clear-keybinds)
(define-workspace-keybinds :super '(:super :shift))

(define-key-chords (wm)
  ((:super :space)
   (#\\t (set-active-layout wm 'tiling))
   (#\\m (set-active-layout wm 'monocle))
   (#\\e (toggle-highlight wm \"emacs\"))
   (#\\r (toggle-repl-server))
   (#\\c (reload-config wm))))
"))

(define portals-conf
  (plain-file "river-portals.conf" "\
[preferred]
default=gtk;
org.freedesktop.impl.portal.ScreenCast=wlr;
org.freedesktop.impl.portal.Screenshot=wlr;
"))

(define action-binds
  (map (match-lambda
         ((key action)
          (nucleotide-bind key action)))
       '(("Mod+J" "(cycle-focus wm :next)")
         ("Mod+K" "(cycle-focus wm :prev)")
         ("Mod+Shift+J" "(move-window wm :next)")
         ("Mod+Shift+K" "(move-window wm :prev)")
         ("Mod+Shift+C" "(close-focused wm)")
         ("Mod+Shift+F" "(toggle-fullscreen wm)")
         ("Mod+Shift+E" "(exit wm)")
         ("Ctrl+Alt+Delete" "(exit wm)"))))

(define dbus-update-activation-environment
  (file-append dbus "/bin/dbus-update-activation-environment"))

(define (nucleotide-services theme)
  (list (home-packages xdg-desktop-portal-wlr xorg-server-xwayland)
        (simple-service 'nucleotide-portals
                        home-xdg-configuration-files-service-type
                        `(("xdg-desktop-portal/river-portals.conf"
                           ,portals-conf)))
        (service home-nucleotide-service-type
                 (home-nucleotide-configuration
                   (settings (list (nucleotide-settings theme)))
                   (entries
                    (cons (nucleotide-autostart
                           dbus-update-activation-environment
                           "WAYLAND_DISPLAY" "XDG_CURRENT_DESKTOP")
                          action-binds))))))
