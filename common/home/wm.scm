;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common home wm)
  #:use-module (guix gexp)
  #:use-module (gnu packages freedesktop)
  #:use-module (gnu packages xdisorg)
  #:use-module (gnu services)
  #:use-module (common home helpers)
  #:use-module (common home niri)
  #:use-module (common home nucleotide)
  #:use-module (common home osd)
  #:use-module (common machines)
  #:use-module (ice-9 match)
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

(define (locked-binds bindings)
  (map (match-lambda
         ((key . command) (wm-bind key command
                                   #:locked? #t))) bindings))

(define audio-binds
  (locked-binds `(("XF86AudioRaiseVolume" ,volume-osd "set-volume"
                   "@DEFAULT_AUDIO_SINK@" "0.1+")
                  ("XF86AudioLowerVolume" ,volume-osd "set-volume"
                   "@DEFAULT_AUDIO_SINK@" "0.1-")
                  ("XF86AudioMute" ,volume-osd "set-mute"
                   "@DEFAULT_AUDIO_SINK@" "toggle")
                  ("XF86AudioMicMute" ,volume-osd "set-mute"
                   "@DEFAULT_AUDIO_SOURCE@" "toggle"))))

(define brightness-binds
  (locked-binds `(("XF86MonBrightnessUp" ,brightness-osd "+10%")
                  ("XF86MonBrightnessDown" ,brightness-osd "10%-"))))

(define (wm-services machine)
  (define theme
    (machine-theme machine))

  (append (list (home-packages wl-clipboard xdg-desktop-portal
                               xdg-desktop-portal-gtk)
                (apply wm-extensions machine
                       'desktop
                       (append brightness-binds
                               (if (machine-audio? machine) audio-binds
                                   '()))))
          (match (machine-wm machine)
            ('niri (niri-services theme))
            ('nucleotide (nucleotide-services theme)))))
