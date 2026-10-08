;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common home waybar)
  #:use-module (guix gexp)
  #:use-module (guix records)
  #:use-module (json)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages window-management)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:use-module (common home helpers)
  #:use-module (common home wm)
  #:use-module (common machines)
  #:use-module (common themes)
  #:export (waybar-services))

(define %glyphs
  '((chevron-left . "\uf053")
    (eye . "\uf06e")
    (eye-slash . "\uf070")
    (volume-xmark . "\uf6a9")
    (volume-off . "\uf026")
    (volume-low . "\uf027")
    (volume-high . "\uf028")
    (sun . "\uf185")
    (charging-station . "\uf5e7")
    (plug . "\uf1e6")
    (battery-empty . "\uf244")
    (battery-quarter . "\uf243")
    (battery-half . "\uf242")
    (battery-three-quarters . "\uf241")
    (battery-full . "\uf240")
    (wifi . "\uf1eb")
    (network-wired . "\uf6ff")
    (circle-xmark . "\uf057")
    (hard-drive . "\uf0a0")))

(define (glyph name)
  (assq-ref %glyphs name))

(define-record-type* <status-module> status-module make-status-module
  status-module?
  (name         status-module-name)
  (config       status-module-config)
  (color        status-module-color (default 'fg_0))
  (state-colors status-module-state-colors (default '()))
  (available?   status-module-available? (default (const #t)))
  (package      status-module-package (default #f))
  (pinned?      status-module-pinned? (default #f)))

(define %status-modules
  (list (status-module
         (name "idle_inhibitor")
         (config `(("format" . "{icon}")
                   ("format-icons" . (("activated" . ,(glyph 'eye))
                                      ("deactivated" . ,(glyph 'eye-slash))))))
         (color 'dim_0)
         (state-colors '(("activated" . br_blue))))
        (status-module
         (name "network")
         (config
          `(("format-wifi" . ,(string-append "{signalStrength}% "
                                             (glyph 'wifi)))
            ("format-ethernet" . ,(string-append "Ethernet "
                                                 (glyph 'network-wired)))
            ("format-linked" . ,(string-append "No IP "
                                               (glyph 'network-wired)))
            ("format-disconnected" . ,(glyph 'circle-xmark))
            ("format-alt" . "{bandwidthDownBits}/{bandwidthUpBits}")))
         (state-colors '(("disconnected" . dim_0)))
         (pinned? #t))
        (status-module
         (name "wireplumber")
         (config `(("format" . "{volume}% {icon}")
                   ("format-muted" . ,(glyph 'volume-xmark))
                   ("format-icons" . ,(vector (glyph 'volume-off)
                                              (glyph 'volume-low)
                                              (glyph 'volume-high)))
                   ("on-click" . "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")))
         (state-colors '(("muted" . dim_0)))
         (available? machine-audio?)
         (package wireplumber))
        (status-module
         (name "backlight")
         (config `(("format" . ,(string-append "{percent}% " (glyph 'sun)))
                   ("on-scroll-up"
                    . "brightnessctl --class=backlight set +5%")
                   ("on-scroll-down"
                    . "brightnessctl --class=backlight set 5%-")))
         (available? machine-mobile?)
         (package brightnessctl))
        (status-module
         (name "battery")
         (config `(("states" . (("warning" . 30)
                                ("critical" . 15)))
                   ("format" . "{capacity}% {icon}")
                   ("format-charging" . ,(string-append
                                          "{capacity}% "
                                          (glyph 'charging-station)))
                   ("format-plugged" . ,(string-append "{capacity}% "
                                                       (glyph 'plug)))
                   ("format-alt" . "{time} {icon}")
                   ("format-icons" . ,(vector (glyph 'battery-empty)
                                              (glyph 'battery-quarter)
                                              (glyph 'battery-half)
                                              (glyph 'battery-three-quarters)
                                              (glyph 'battery-full)))))
         (state-colors '(("charging" . green)
                         ("plugged" . green)
                         ("warning" . yellow)
                         ("critical" . red)))
         (available? machine-mobile?)
         (pinned? #t))
        (status-module
         (name "disk")
         (config `(("interval" . 30)
                   ("format" . ,(string-append "{percentage_used}% "
                                               (glyph 'hard-drive)))
                   ("path" . "/")))
         (color 'dim_0))))

(define (machine-status-modules machine)
  (filter (lambda (module)
            ((status-module-available? module) machine))
          %status-modules))

(define calendar-tooltip
  "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>")

(define %window-modules
  '((niri . (("modules-left" . #("niri/workspaces" "niri/window"))
             ("niri/window" . (("max-length" . 60)))))
    (nucleotide . (("modules-left" . #("wlr/taskbar"))
                   ("wlr/taskbar" . (("format" . "{title:.40}")
                                     ("tooltip-format" . "{title}")))))))

(define (right-modules modules)
  (define-values (pinned drawer)
    (partition status-module-pinned? modules))

  `(("modules-right"
     . ,(list->vector (cons "group/status" (map status-module-name pinned))))
    ("group/status"
     . (("orientation" . "inherit")
        ("drawer" . (("click-to-reveal" . #t)
                     ("transition-left-to-right" . #f)))
        ("modules"
         . ,(list->vector
             (cons "custom/expand"
                   (append (map status-module-name drawer)
                           '("tray")))))))))

(define (text-module text)
  `(("format" . ,text)
    ("tooltip" . #f)))

(define (waybar-config machine)
  (define modules (machine-status-modules machine))

  `(("height" . 30)
    ,@(assq-ref %window-modules (machine-wm machine))
    ("modules-center" . #("clock#time" "custom/dot" "clock#date"))
    ,@(right-modules modules)

    ("clock#time" . (("format" . "{:%H:%M}")
                     ("align" . 1.0)
                     ("tooltip-format" . ,calendar-tooltip)))
    ("custom/dot" . ,(text-module "·"))
    ("clock#date" . (("format" . "{:%a %d %b}")
                     ("align" . 0.0)
                     ("tooltip-format" . ,calendar-tooltip)))
    ("custom/expand" . ,(text-module (glyph 'chevron-left)))
    ("tray" . (("spacing" . 10)))

    ,@(map (lambda (module)
             (cons (status-module-name module)
                   (status-module-config module)))
           modules)))

(define (waybar-style theme)
  (define (colored selector name)
    `((,selector) ("color" . ,(color theme name))))

  (define (status-module-rules module)
    (let ((selector (string-append "#" (status-module-name module))))
      (cons (colored selector (status-module-color module))
            (map (match-lambda
                   ((state . name)
                    (colored (string-append selector "." state) name)))
                 (status-module-state-colors module)))))

  (css-file
   "waybar-style.css"
   `((("*")
      ("font-size" . "15px")
      ("font-family" . "\"Aporetic Sans Mono\"")
      ("border" . "none")
      ("border-radius" . "0")
      ("min-height" . "0")
      ("box-shadow" . "none"))
     (("window#waybar")
      ("background" . ,(color theme 'bg_0))
      ("color" . ,(color theme 'fg_0))
      ("border-bottom" . ,(string-append "1px solid " (color theme 'bg_2))))
     (("#workspaces button" "#taskbar button")
      ("padding" . "0 10px")
      ("color" . ,(color theme 'dim_0))
      ("background" . "transparent"))
     (("#workspaces button:hover" "#taskbar button:hover")
      ("color" . ,(color theme 'fg_0))
      ("background" . "transparent"))
     (("#workspaces button.active" "#workspaces button.focused"
       "#taskbar button.active")
      ("color" . ,(color theme 'fg_0))
      ("box-shadow" . ,(string-append "inset 0 -2px "
                                      (color theme 'br_blue))))
     (("#workspaces button.urgent")
      ("color" . ,(color theme 'red))
      ("box-shadow" . ,(string-append "inset 0 -2px " (color theme 'red))))
     (("#window")
      ("color" . ,(color theme 'dim_0))
      ("padding" . "0 14px"))
     (("#clock.time" "#clock.date")
      ("min-width" . "100px")
      ("padding" . "0"))
     (("#clock.date")
      ("color" . ,(color theme 'dim_0))
      ("font-size" . "13px"))
     (("#custom-dot")
      ("color" . ,(color theme 'border))
      ("padding" . "0 10px"))
     ((,@(map (lambda (module)
                (string-append "#" (status-module-name module)))
              %status-modules)
       "#custom-expand" "#tray")
      ("padding" . "0 10px"))
     ,@(append-map status-module-rules %status-modules)
     (("#battery.critical")
      ("font-weight" . "bold"))
     (("#custom-expand")
      ("color" . ,(color theme 'border))
      ("transition" . "color 300ms"))
     ,(colored "#custom-expand:hover" 'fg_0)
     ,(colored "#status:hover #custom-expand" 'fg_0))))

(define (waybar-config-file machine)
  (plain-file "waybar-config"
              (scm->json-string (vector (waybar-config machine)) #:pretty #t)))

(define (waybar-services machine)
  (list (apply home-packages waybar
               (filter-map status-module-package
                           (machine-status-modules machine)))
        (simple-service 'waybar-config
                        home-xdg-configuration-files-service-type
                        `(("waybar/config" ,(waybar-config-file machine))
                          ("waybar/style.css"
                           ,(waybar-style (machine-theme machine)))))
        (wm-extensions (machine-wm machine) 'waybar-autostart
                       (wm-autostart (file-append waybar "/bin/waybar")))))
