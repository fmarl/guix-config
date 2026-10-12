;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common home waybar)
  #:use-module (guix gexp)
  #:use-module (guix records)
  #:use-module (gnu home services)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages window-management)
  #:use-module (common home helpers)
  #:use-module (common home theme)
  #:use-module (common home wm)
  #:use-module (common machines)
  #:use-module (common themes)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:export (waybar-services))

(define %glyphs
  '((chevron-left . "\uf053") (eye . "\uf06e")
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

(define (shell-command program . arguments)
  #~(string-join (list #$program
                       #$@arguments)))

(define (set-brightness change)
  (shell-command (file-append brightnessctl "/bin/brightnessctl")
                 "--class=backlight" "set" change))

(define-record-type* <status-module> status-module make-status-module
  status-module?
  (name status-module-name)
  (config status-module-config)
  (color status-module-color
         (default 'fg_0))
  (state-colors status-module-state-colors
                (default '()))
  (available? status-module-available?
              (default (const #t)))
  (pinned? status-module-pinned?
           (default #f)))

(define %status-modules
  (list (status-module (name "idle_inhibitor")
                       (config `(("format" . "{icon}") ("format-icons" ("activated"
                                                                        unquote
                                                                        (glyph 'eye))
                                                        ("deactivated" unquote
                                                         (glyph 'eye-slash)))))
                       (color 'dim_0)
                       (state-colors '(("activated" . br_blue))))
        (status-module (name "network")
                       (config `(("format-wifi" unquote
                                  (string-append "{signalStrength}% "
                                                 (glyph 'wifi)))
                                 ("format-ethernet" unquote
                                  (string-append "Ethernet "
                                                 (glyph 'network-wired)))
                                 ("format-linked" unquote
                                  (string-append "No IP "
                                                 (glyph 'network-wired)))
                                 ("format-disconnected" unquote
                                  (glyph 'circle-xmark))
                                 ("format-alt" . "{bandwidthDownBits}/{bandwidthUpBits}")))
                       (state-colors '(("disconnected" . dim_0)))
                       (pinned? #t))
        (status-module (name "wireplumber")
                       (config `(("format" . "{volume}% {icon}") ("format-muted"
                                                                  unquote
                                                                  (glyph 'volume-xmark))
                                 ("format-icons" unquote
                                  (vector (glyph 'volume-off)
                                          (glyph 'volume-low)
                                          (glyph 'volume-high)))
                                 ("on-click" unquote
                                  (shell-command (file-append wireplumber
                                                              "/bin/wpctl")
                                                 "set-mute"
                                                 "@DEFAULT_AUDIO_SINK@"
                                                 "toggle"))))
                       (state-colors '(("muted" . dim_0)))
                       (available? machine-audio?))
        (status-module (name "backlight")
                       (config `(("format" unquote
                                  (string-append "{percent}% "
                                                 (glyph 'sun)))
                                 ("on-scroll-up" unquote
                                  (set-brightness "+5%"))
                                 ("on-scroll-down" unquote
                                  (set-brightness "5%-"))))
                       (available? machine-mobile?))
        (status-module (name "battery")
                       (config `(("states" ("warning" . 30)
                                  ("critical" . 15))
                                 ("format" . "{capacity}% {icon}")
                                 ("format-charging" unquote
                                  (string-append "{capacity}% "
                                                 (glyph 'charging-station)))
                                 ("format-plugged" unquote
                                  (string-append "{capacity}% "
                                                 (glyph 'plug)))
                                 ("format-alt" . "{time} {icon}")
                                 ("format-icons" unquote
                                  (vector (glyph 'battery-empty)
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
        (status-module (name "disk")
                       (config `(("interval" . 30) ("format" unquote
                                                    (string-append
                                                     "{percentage_used}% "
                                                     (glyph 'hard-drive)))
                                 ("path" . "/home")))
                       (color 'dim_0))))

(define (machine-status-modules machine)
  (filter (lambda (module)
            ((status-module-available? module)
             machine)) %status-modules))

(define calendar-tooltip
  "<big>{:%Y %B}</big>
<tt><small>{calendar}</small></tt>")

(define %window-modules
  '((niri ("modules-left" . #("niri/workspaces" "niri/window"))
          ("niri/window" ("max-length" . 60)))
    (nucleotide ("modules-left" . #("wlr/taskbar"))
                ("wlr/taskbar" ("format" . "{title:.40}")
                 ("tooltip-format" . "{title}")))))

(define (right-modules modules)
  (define-values (pinned drawer)
                 (partition status-module-pinned? modules))

  `(("modules-right" unquote
     (list->vector (cons "group/status"
                         (map status-module-name pinned))))
    ("group/status" ("orientation" . "inherit")
     ("drawer" ("click-to-reveal" . #t)
      ("transition-left-to-right" . #f))
     ("modules" unquote
      (list->vector (cons "custom/expand"
                          (append (map status-module-name drawer)
                                  '("tray"))))))))

(define (text-module text)
  `(("format" unquote text)
    ("tooltip" . #f)))

(define (waybar-config machine)
  (define modules
    (machine-status-modules machine))

  `(("height" . 32) ,@(assq-ref %window-modules
                                (machine-wm machine))
    ("modules-center" . #("clock#time" "custom/dot" "clock#date"))
    ,@(right-modules modules)

    ("clock#time" ("format" . "{:%H:%M}")
     ("align" . 1.0)
     ("tooltip-format" unquote calendar-tooltip))
    ("custom/dot" unquote
     (text-module "·"))
    ("clock#date" ("format" . "{:%a %d %b}")
     ("align" . 0.0)
     ("tooltip-format" unquote calendar-tooltip))
    ("custom/expand" unquote
     (text-module (glyph 'chevron-left)))
    ("tray" ("spacing" . 10))

    ,@(map (lambda (module)
             (cons (status-module-name module)
                   (status-module-config module))) modules)))

(define (waybar-style theme)
  (define (colored selector name)
    `((,selector)
      ("color" unquote
       (color theme name))))

  (define (status-module-rules module)
    (let ((selector (string-append "#"
                                   (status-module-name module))))
      (cons (colored selector
                     (status-module-color module))
            (map (match-lambda
                   ((state . name) (colored (string-append selector "." state)
                                            name)))
                 (status-module-state-colors module)))))

  (define (translucent name alpha)
    (color-rgba theme name alpha))

  (define status-selectors
    (append (map (lambda (module)
                   (string-append "#"
                                  (status-module-name module)))
                 %status-modules)
            '("#custom-expand" "#tray")))

  (define (px n)
    (string-append (number->string n) "px"))

  (css-file "waybar-style.css"
            `((("*")
               ("font-family" unquote
                (string-append "\"" %sans-font "\", sans-serif"))
               ("font-size" . "13px")
               ("font-weight" . "500")
               ("font-feature-settings" . "\"tnum\"")
               ("border" . "none")
               ("border-radius" . "0")
               ("min-height" . "0")
               ("box-shadow" . "none")
               ("text-shadow" . "none"))
              (("window#waybar")
               ("background" unquote
                (translucent 'bg_0 0.7))
               ("color" unquote
                (color theme
                       'fg_0))
               ("border-bottom" unquote
                (string-append "1px solid "
                               (translucent 'fg_0 0.1))))
              (("#workspaces")
               ("margin" . "5px 0 5px 8px")
               ("padding" . "2px")
               ("border-radius" unquote
                (px (+ %small-corner-radius 2)))
               ("background" unquote
                (translucent 'fg_0 0.07)))
              (("#workspaces button" "#taskbar button")
               ("margin" . "0 1px")
               ("padding" . "0 9px")
               ("border-radius" unquote
                (px %small-corner-radius))
               ("color" unquote
                (translucent 'fg_0 0.55))
               ("background" . "transparent")
               ("transition" . "background 200ms, color 200ms"))
              (("#workspaces button:hover" "#taskbar button:hover")
               ("color" unquote
                (color theme
                       'fg_0)))
              (("#workspaces button.active" "#workspaces button.focused"
                "#taskbar button.active")
               ("color" unquote
                (color theme
                       'fg_0))
               ("background" unquote
                (color theme
                       'bg_raised))
               ("box-shadow" unquote
                (string-append "0 1px 2px "
                               (translucent 'fg_0 0.18))))
              (("#workspaces button.urgent")
               ("color" unquote
                (color theme
                       'red)))
              (("#taskbar")
               ("margin" . "5px 0 5px 8px"))
              (("#window")
               ("padding" . "0 14px")
               ("font-weight" . "700"))
              (("#clock.time" "#clock.date")
               ("min-width" . "88px"))
              (("#clock.time")
               ("font-weight" . "600"))
              (("#clock.date")
               ("color" unquote
                (translucent 'fg_0 0.6)))
              (("#custom-dot")
               ("color" unquote
                (translucent 'fg_0 0.3))
               ("padding" . "0 4px"))
              (,status-selectors ("margin" . "4px 1px")
               ("padding" . "0 9px")
               ("border-radius" unquote
                (px %small-corner-radius))
               ("transition" . "background 200ms"))
              (,(map (lambda (selector)
                       (string-append selector ":hover")) status-selectors) ("background"
                                                                             unquote
                                                                             (translucent 'fg_0
                                                                              0.08)))
              (("#tray")
               ("margin-right" . "8px"))
              ,@(append-map status-module-rules %status-modules)
              (("#battery.critical")
               ("font-weight" . "700"))
              (("#custom-expand")
               ("color" unquote
                (translucent 'fg_0 0.35))
               ("transition" . "background 200ms, color 200ms"))
              ,(colored "#status:hover #custom-expand"
                        'fg_0)
              (("tooltip")
               ("background" unquote
                (translucent 'bg_popup 0.97))
               ("border" unquote
                (string-append "1px solid "
                               (color theme
                                      'border)))
               ("border-radius" unquote
                (px %corner-radius)))
              (("tooltip label")
               ("color" unquote
                (color theme
                       'fg_0))
               ("padding" . "4px 6px")))))

(define (waybar-services machine)
  (list (home-packages waybar)
        (simple-service 'waybar-config
                        home-xdg-configuration-files-service-type
                        `(("waybar/config" ,(json-file "waybar-config"
                                                       (vector (waybar-config
                                                                machine))))
                          ("waybar/style.css" ,(waybar-style (machine-theme
                                                              machine)))))
        (wm-extensions machine
                       'waybar-wm
                       (wm-autostart (file-append waybar "/bin/waybar"))
                       (wm-layer-rule "^waybar$"
                                      #:hide-from-screencast? #t))))
