;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common home nucleotide)
  #:use-module (guix gexp)
  #:use-module (guix records)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:use-module (gnu services)
  #:use-module (gnu packages freedesktop)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages image)
  #:use-module (gnu packages xorg)
  #:use-module (gnu home services)
  #:use-module (common home helpers)
  #:use-module (common themes)
  #:export (home-nucleotide-service-type
            nucleotide-autostart
            nucleotide-bind
            nucleotide-spawn
            nucleotide-services))

(define (nucleotide-spawn program . arguments)
  "Return the spawn action for PROGRAM, a string or file-like."
  `(spawn ,program ,@arguments))

(define (nucleotide-autostart program . arguments)
  `(autostart ,program ,@arguments))

(define (nucleotide-bind key action)
  "Bind KEY to ACTION, Lisp code as a string or an action returned by
nucleotide-spawn."
  `(bind ,key ,action))

(define (lisp-string value)
  (match value
    ((? string?) (list (object->string value)))
    (_ (list "\"" value "\""))))

(define (lisp-strings values)
  (append-map (lambda (value)
                (cons " " (lisp-string value)))
              values))

(define %modifiers
  '(("Shift" . ":shift") ("Ctrl" . ":ctrl") ("Alt" . ":alt")
    ("Mod" . ":super") ("Super" . ":super")))

(define %keysyms
  '(("Return" . ":return")
    ("Print" . ":print")
    ("Delete" . ":delete")
    ("XF86MonBrightnessUp" . "#x1008ff02")
    ("XF86MonBrightnessDown" . "#x1008ff03")
    ("XF86AudioLowerVolume" . "#x1008ff11")
    ("XF86AudioMute" . "#x1008ff12")
    ("XF86AudioRaiseVolume" . "#x1008ff13")
    ("XF86AudioMicMute" . "#x1008ffb2")))

(define (keysym key)
  (cond ((= (string-length key) 1)
         (string-append "#\\" (string-downcase key)))
        ((assoc-ref %keysyms key))
        (else (error "unknown nucleotide key" key))))

(define (modifier name)
  (or (assoc-ref %modifiers name)
      (error "unknown nucleotide modifier" name)))

(define (action->lisp action)
  (match action
    ((? string?) (list action))
    (('spawn . command) `("(spawn (list" ,@(lisp-strings command) "))"))))

(define (bind->lisp bind)
  (match bind
    ((key action)
     (match (reverse (string-split key #\+))
       ((key . modifiers)
        `("\n  ((" ,(string-join (map modifier (reverse modifiers)) " ")
          ") " ,(keysym key) " " ,@(action->lisp action) ")"))))))

(define (autostart->lisp command)
  `("\n    (" ,@(cdr (lisp-strings command)) ")"))

(define (rgba theme name)
  (let ((hex (color theme name)))
    (string-join (map (lambda (start)
                        (number->string
                         (string->number (substring hex start (+ start 2)) 16)))
                      '(1 3 5))
                 " ")))

(define (nucleotide-settings theme)
  (string-append "(defparameter *focused-border-rgba* '("
                 (rgba theme 'br_blue) " 255))
(defparameter *unfocused-border-rgba* '(" (rgba theme 'border) " 255))

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

(define-record-type* <home-nucleotide-configuration>
  home-nucleotide-configuration make-home-nucleotide-configuration
  home-nucleotide-configuration?
  (theme   home-nucleotide-configuration-theme)
  (entries home-nucleotide-configuration-entries (default '())))

(define (nucleotide-config-file config)
  (define entries (home-nucleotide-configuration-entries config))

  (apply mixed-text-file "init.lisp"
         (append (list (nucleotide-settings
                        (home-nucleotide-configuration-theme config)))
                 '("\n(defparameter *autostart-programs*\n  '(")
                 (append-map autostart->lisp
                             (tagged-entries entries 'autostart))
                 '("))\n\n(define-keybinds (wm)")
                 (append-map bind->lisp (tagged-entries entries 'bind))
                 '(")\n"))))

(define home-nucleotide-service-type
  (service-type (name 'home-nucleotide)
                (extensions
                 (list (service-extension
                        home-xdg-configuration-files-service-type
                        (lambda (config)
                          `(("nucleotide/init.lisp"
                             ,(nucleotide-config-file config)))))))
                (compose concatenate)
                (extend (lambda (config entries)
                          (home-nucleotide-configuration
                           (inherit config)
                           (entries (append
                                     (home-nucleotide-configuration-entries
                                      config)
                                     entries)))))
                (description "Generate the nucleotide init file from the
autostart programs and key bindings that other services contribute through
nucleotide-autostart and nucleotide-bind.")))

(define portals-conf
  (plain-file "river-portals.conf"
              "[preferred]
default=gtk;
org.freedesktop.impl.portal.ScreenCast=wlr;
org.freedesktop.impl.portal.Screenshot=wlr;
"))

(define screenshot
  (shell-script "screenshot"
                "dir=\"$HOME/Pictures/Screenshots\"\n"
                "mkdir -p \"$dir\"\n"
                "file=\"$dir/Screenshot from $(date '+%Y-%m-%d %H-%M-%S').png\"\n"
                "case \"$1\" in\n"
                "    screen) " grim "/bin/grim \"$file\" ;;\n"
                "    *) " grim "/bin/grim -g \"$(" slurp "/bin/slurp)\" \"$file\" ;;\n"
                "esac\n"))

(define action-binds
  (map (match-lambda
         ((key action) (nucleotide-bind key action)))
       '(("Mod+J" "(cycle-focus wm :next)")
         ("Mod+K" "(cycle-focus wm :prev)")
         ("Mod+Shift+J" "(move-window wm :next)")
         ("Mod+Shift+K" "(move-window wm :prev)")
         ("Mod+Shift+C" "(close-focused wm)")
         ("Mod+Shift+F" "(toggle-fullscreen wm)")
         ("Mod+Shift+E" "(exit wm)")
         ("Ctrl+Alt+Delete" "(exit wm)"))))

(define screenshot-binds
  (list (nucleotide-bind "Print" (nucleotide-spawn screenshot))
        (nucleotide-bind "Ctrl+Print" (nucleotide-spawn screenshot "screen"))))

(define dbus-update-activation-environment
  (file-append dbus "/bin/dbus-update-activation-environment"))

(define (nucleotide-services theme)
  (list (home-packages xdg-desktop-portal-wlr xorg-server-xwayland)
        (simple-service 'nucleotide-portals
                        home-xdg-configuration-files-service-type
                        `(("xdg-desktop-portal/river-portals.conf" ,portals-conf)))
        (service home-nucleotide-service-type
                 (home-nucleotide-configuration
                  (theme theme)
                  (entries
                   (cons (nucleotide-autostart
                          dbus-update-activation-environment
                          "WAYLAND_DISPLAY" "XDG_CURRENT_DESKTOP")
                         (append action-binds screenshot-binds)))))))
