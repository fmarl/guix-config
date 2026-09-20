;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common home wm)
  #:use-module (guix gexp)
  #:use-module (ice-9 match)
  #:use-module (gnu services)
  #:use-module (gnu packages freedesktop)
  #:use-module (gnu packages gnome)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages pdf)
  #:use-module (gnu packages terminals)
  #:use-module (gnu packages xdisorg)
  #:use-module (sagittarius locked image-viewers)
  #:use-module (sagittarius locked pdf)
  #:use-module (sagittarius locked video)
  #:use-module (common home helpers)
  #:use-module (common home bemenu)
  #:use-module (common home emacs)
  #:use-module (common home niri)
  #:use-module (common home nucleotide)
  #:use-module (common machines)
  #:use-module (srfi srfi-1)
  #:export (wm-autostart wm-bind wm-layer-rule wm-window-rule wm-extensions
                         wm-services))

(define (wm-autostart program . arguments)
  `(autostart ,program
              ,@arguments))

(define* (wm-layer-rule namespace
                        #:key hide-from-screencast?)
  `(layer-rule ,namespace
               ,hide-from-screencast?))

(define* (wm-window-rule app-id
                         #:key title floating? hide-from-screencast?)
  `(window-rule ,app-id
                ,title
                ,floating?
                ,hide-from-screencast?))

(define (screencast-properties hide-from-screencast?)
  (if hide-from-screencast?
      '((block-out-from "screencast"))
      '()))

(define* (wm-bind key command
                  #:key title locked?)
  `(bind ,key
         ,command
         ,title
         ,locked?))

(define (entry->niri entry)
  (match entry
    (((quote autostart) . command) (apply niri-spawn-at-startup command))
    (('bind key command title locked?)
     (niri-bind key
                (apply niri-spawn command)
                #:title title
                #:allow-when-locked? locked?))
    (('layer-rule namespace hide-from-screencast?)
     (apply niri-layer-rule namespace
            (screencast-properties hide-from-screencast?)))
    (('window-rule app-id title floating? hide-from-screencast?)
     (apply niri-window-rule
            `(#:app-id ,app-id
              ,@(if title
                    `(#:title ,title)
                    '()))
            (append (if floating?
                        '((open-floating #t))
                        '())
                    (screencast-properties hide-from-screencast?))))))

(define (entry->nucleotide entry)
  (match entry
    (((quote autostart) . command) (apply nucleotide-autostart command))
    (('bind key command _ _)
     (nucleotide-bind key
                      (apply nucleotide-spawn command)))
    (('layer-rule _ _)
     #f)
    (('window-rule _ _ _ _)
     #f)))

(define (wm-extensions machine name . entries)
  (match (machine-wm machine)
    ('niri (simple-service name home-niri-service-type
                           (map entry->niri entries)))
    ('nucleotide (simple-service name home-nucleotide-service-type
                                 (filter-map entry->nucleotide entries)))))

(define (launcher-binds theme)
  (list (wm-bind "Mod+Shift+Return"
                 (list (file-append alacritty "/bin/alacritty"))
                 #:title "Open alacritty")
        (wm-bind "Mod+P"
                 (list (bemenu-run theme))
                 #:title "Run bemenu")
        (wm-bind "Mod+E"
                 (emacsclient-command "-c" "-n")
                 #:title "Open Emacs")
        (wm-bind "Mod+Shift+D"
                 (emacsclient-command "-c" "-n" "-e" "(dirvish-dwim)")
                 #:title "Start dirvish")))

(define (media-binds bindings)
  (map (match-lambda
         ((key . command) (wm-bind key command
                                   #:locked? #t))) bindings))

(define audio-binds
  (let ((wpctl (file-append wireplumber "/bin/wpctl")))
    (media-binds `(("XF86AudioRaiseVolume" ,wpctl "set-volume"
                    "@DEFAULT_AUDIO_SINK@" "0.1+")
                   ("XF86AudioLowerVolume" ,wpctl "set-volume"
                    "@DEFAULT_AUDIO_SINK@" "0.1-")
                   ("XF86AudioMute" ,wpctl "set-mute" "@DEFAULT_AUDIO_SINK@"
                    "toggle")
                   ("XF86AudioMicMute" ,wpctl "set-mute"
                    "@DEFAULT_AUDIO_SOURCE@" "toggle")))))

(define brightness-binds
  (let ((brightnessctl (file-append brightnessctl "/bin/brightnessctl")))
    (media-binds `(("XF86MonBrightnessUp" ,brightnessctl "--class=backlight"
                    "set" "+10%")
                   ("XF86MonBrightnessDown" ,brightnessctl "--class=backlight"
                    "set" "10%-")))))

(define (wm-services machine)
  (define theme
    (machine-theme machine))

  (append (list (home-packages wl-clipboard
                               xdg-desktop-portal
                               xdg-desktop-portal-gtk
                               imv-locked
                               zathura-locked
                               zathura-pdf-mupdf
                               mpv-locked)
                (apply wm-extensions machine
                       'desktop
                       (append (launcher-binds theme) brightness-binds
                               (if (machine-audio? machine) audio-binds
                                   '()))))
          (match (machine-wm machine)
            ('niri (niri-services theme))
            ('nucleotide (nucleotide-services theme)))))
