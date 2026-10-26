;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common home wm)
  #:use-module (guix gexp)
  #:use-module (gnu packages freedesktop)
  #:use-module (gnu packages music)
  #:use-module (gnu packages xdisorg)
  #:use-module (gnu services)
  #:use-module (common home helpers)
  #:use-module (common home niri)
  #:use-module (common home nucleotide)
  #:use-module (sagittarius home services wm)
  #:use-module (common home osd)
  #:use-module (common machines)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-9)
  #:export (wm-autostart
            wm-bind
            wm-layer-rule
            wm-window-rule
            wm-extensions
            wm-services))

(define-record-type <autostart>
  (make-autostart command)
  autostart?
  (command autostart-command))

(define-record-type <binding>
  (make-binding key command title locked?)
  binding?
  (key     binding-key)
  (command binding-command)
  (title   binding-title)
  (locked? binding-locked?))

(define-record-type <layer-rule>
  (make-layer-rule namespace hide-from-screencast?)
  layer-rule?
  (namespace             layer-rule-namespace)
  (hide-from-screencast? layer-rule-hide-from-screencast?))

(define-record-type <window-rule>
  (make-window-rule app-id title floating? hide-from-screencast?)
  window-rule?
  (app-id                window-rule-app-id)
  (title                 window-rule-title)
  (floating?             window-rule-floating?)
  (hide-from-screencast? window-rule-hide-from-screencast?))

(define (wm-autostart program . arguments)
  (make-autostart (cons program arguments)))

(define* (wm-bind key command #:key title locked?)
  (make-binding key command title locked?))

(define* (wm-layer-rule namespace #:key hide-from-screencast?)
  (make-layer-rule namespace hide-from-screencast?))

(define* (wm-window-rule app-id #:key title floating? hide-from-screencast?)
  (make-window-rule app-id title floating? hide-from-screencast?))

(define (screencast-properties hide-from-screencast?)
  (if hide-from-screencast?
      '((block-out-from "screencast"))
      '()))

(define (entry->niri entry)
  (cond
   ((autostart? entry)
    (apply niri-spawn-at-startup (autostart-command entry)))
   ((binding? entry)
    (niri-bind (binding-key entry)
               (apply niri-spawn (binding-command entry))
               #:title (binding-title entry)
               #:allow-when-locked? (binding-locked? entry)))
   ((layer-rule? entry)
    (apply niri-layer-rule
           (layer-rule-namespace entry)
           (screencast-properties
            (layer-rule-hide-from-screencast? entry))))
   ((window-rule? entry)
    (apply niri-window-rule
           `(#:app-id ,(window-rule-app-id entry)
             ,@(if (window-rule-title entry)
                   `(#:title ,(window-rule-title entry))
                   '()))
           (append (if (window-rule-floating? entry)
                       '((open-floating #t))
                       '())
                   (screencast-properties
                    (window-rule-hide-from-screencast? entry)))))
   (else
    (error "unknown wm entry:" entry))))

(define (entry->nucleotide entry)
  (cond
   ((autostart? entry)
    (apply nucleotide-autostart (autostart-command entry)))
   ((binding? entry)
    (nucleotide-bind (binding-key entry)
                     (apply nucleotide-spawn (binding-command entry))))
   ((or (layer-rule? entry)
        (window-rule? entry))
    #f)
   (else
    (error "unknown wm entry:" entry))))

(define (wm-extensions machine name . entries)
  (match (machine-wm machine)
    ('niri
     (simple-service name home-niri-service-type
                     (map entry->niri entries)))
    ('nucleotide
     (simple-service name home-nucleotide-service-type
                     (filter-map entry->nucleotide entries)))))

(define (locked-binds bindings)
  (map (match-lambda
         ((key . command)
          (wm-bind key command #:locked? #t)))
       bindings))

(define playerctl-bin
  (file-append playerctl "/bin/playerctl"))

(define audio-binds
  (locked-binds
   `(("XF86AudioRaiseVolume"
      ,volume-osd "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1+")
     ("XF86AudioLowerVolume"
      ,volume-osd "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1-")
     ("XF86AudioMute"
      ,volume-osd "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle")
     ("XF86AudioMicMute"
      ,volume-osd "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle")
     ("XF86AudioPlay" ,playerctl-bin "play-pause")
     ("XF86AudioNext" ,playerctl-bin "next")
     ("XF86AudioPrev" ,playerctl-bin "previous"))))

(define brightness-binds
  (locked-binds
   `(("XF86MonBrightnessUp" ,brightness-osd "+10%")
     ("XF86MonBrightnessDown" ,brightness-osd "10%-"))))

(define (wm-services machine)
  (define theme
    (machine-theme machine))

  (append (list (home-packages wl-clipboard
                               xdg-desktop-portal
                               xdg-desktop-portal-gtk)
                (apply wm-extensions machine 'desktop
                       (append brightness-binds
                               (if (machine-audio? machine)
                                   audio-binds
                                   '()))))
          (match (machine-wm machine)
            ('niri (niri-services theme))
            ('nucleotide (nucleotide-services theme)))))
