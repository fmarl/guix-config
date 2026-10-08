;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common home waybar)
  #:use-module (guix gexp)
  #:use-module (json)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-26)
  #:use-module (gnu packages gnome)
  #:use-module (gnu packages window-management)
  #:use-module (gnu packages linux)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:use-module (common home helpers)
  #:use-module (common home wm)
  #:use-module (common machines)
  #:use-module (common themes)
  #:export (waybar-services))

(define %status-modules
  '("idle_inhibitor" "network" "wireplumber" "memory" "cpu"))

(define (status-modules machine)
  (append (if (machine-audio? machine)
              %status-modules
              (delete "wireplumber" %status-modules))
          (if (machine-mobile? machine) '("battery") '())
          '("disk")))

(define %clock-formats
  '("{:%a}" "{:%H:%M}" "{:%d.%m}"))

(define (clock-name index)
  (string-append "clock#" (number->string index)))

(define (segment module)
  (list "custom/left-arrow-dark" module "custom/left-arrow-light"))

(define %pinned-modules
  '("network" "battery"))

(define (right-modules modules)
  `(("modules-right"
     . ,(list->vector
         (cons "group/status"
               (append-map segment
                           (lset-intersection equal? modules
                                              %pinned-modules)))))
    ("group/status"
     . (("orientation" . "inherit")
        ("drawer" . (("click-to-reveal" . #t)
                     ("transition-left-to-right" . #f)))
        ("modules"
         . ,(list->vector
             (cons "custom/expand"
                   (append-map segment
                               (append (lset-difference equal? modules
                                                        %pinned-modules)
                                       '("tray"))))))))))

(define (arrow glyph)
  `(("format" . ,glyph)
    ("tooltip" . #f)))

(define calendar-tooltip
  "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>")

(define (clock-modules)
  (map (lambda (index format)
         `(,(clock-name index) . (("format" . ,format)
                                  ("tooltip-format" . ,calendar-tooltip))))
       (iota (length %clock-formats) 1)
       %clock-formats))

(define %window-modules
  `((niri . (("modules-left" . #("niri/workspaces"
                                 "custom/right-arrow-dark"
                                 "niri/window"))
             ("niri/window" . (("max-length" . 60)))))
    (nucleotide . (("modules-left" . #("wlr/taskbar"
                                       "custom/right-arrow-dark"))
                   ("wlr/taskbar" . (("format" . "{title:.40}")
                                     ("tooltip-format" . "{title}")))))))

(define (waybar-config machine)
  `(,@(assq-ref %window-modules (machine-wm machine))
    ("modules-center" . #("custom/left-arrow-dark"
                          "clock#1"
                          "custom/left-arrow-light"
                          "custom/left-arrow-dark"
                          "clock#2"
                          "custom/right-arrow-dark"
                          "custom/right-arrow-light"
                          "clock#3"
                          "custom/right-arrow-dark"))
    ,@(right-modules (status-modules machine))

    ("custom/left-arrow-dark" . ,(arrow ""))
    ("custom/left-arrow-light" . ,(arrow ""))
    ("custom/right-arrow-dark" . ,(arrow ""))
    ("custom/right-arrow-light" . ,(arrow ""))
    ("custom/expand" . ,(arrow ""))

    ,@(clock-modules)

    ("idle_inhibitor" . (("format" . "{icon}")
                         ("format-icons" . (("activated" . "")
                                            ("deactivated" . "")))))

    ("wireplumber" . (("format" . "{volume}% {icon}")
                      ("format-muted" . "")
                      ("format-icons" . #("" "" ""))
                      ("on-click" . "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")))

    ("disk" . (("interval" . 30)
               ("format" . "Disk {percentage_used:2}%")
               ("path" . "/")))

    ("tray" . (("spacing" . 10)))
    ("cpu" . (("format" . "{usage}% ")))
    ("memory" . (("format" . "{}% ")))

    ("battery" . (("states" . (("warning" . 30)
                               ("critical" . 15)))
                  ("format" . "{capacity}% {icon}")
                  ("format-charging" . "{capacity}% ")
                  ("format-plugged" . "{capacity}% ")
                  ("format-alt" . "{time} {icon}")
                  ("format-icons" . #("" "" "" "" ""))))

    ("network" . (("format-wifi" . "({signalStrength}%) ")
                  ("format-ethernet" . "Ethernet ")
                  ("format-linked" . "Ethernet (No IP) ")
                  ("format-disconnected" . "Disconnected ")
                  ("format-alt" . "{bandwidthDownBits}/{bandwidthUpBits}")))))

(define %styled-status-modules
  (map (cut string-append "#" <>)
       (append %status-modules '("battery" "disk"))))

(define %clock-selectors
  (map (lambda (index)
         (string-append "#clock." (number->string index)))
       (iota (length %clock-formats) 1)))

(define (foreground theme selector name)
  `((,selector) ("color" . ,(color theme name))))

(define (waybar-style theme)
  (css-file
   "waybar-style.css"
   `((("*")
      ("font-size" . "18px")
      ("font-family" . "\"Aporetic Sans Mono\""))
     (("window#waybar")
      ("background" . ,(color theme 'bg_0))
      ("color" . ,(color theme 'fg_0)))
     (("#custom-right-arrow-dark" "#custom-left-arrow-dark")
      ("color" . ,(color theme 'bg_1)))
     (("#custom-right-arrow-light" "#custom-left-arrow-light")
      ("color" . ,(color theme 'bg_0))
      ("background" . ,(color theme 'bg_1)))
     (("#workspaces" "#taskbar" ,@%clock-selectors ,@%styled-status-modules
       "#tray")
      ("background" . ,(color theme 'bg_1)))
     (("#workspaces button" "#taskbar button")
      ("padding" . "0 2px")
      ("color" . ,(color theme 'fg_0)))
     (("#workspaces button.active" "#workspaces button.focused"
       "#taskbar button.active")
      ("color" . ,(color theme 'br_blue)))
     ,(foreground theme "#workspaces button.urgent" 'red)
     (("#workspaces button:hover" "#taskbar button:hover")
      ("box-shadow" . "inherit")
      ("text-shadow" . "inherit")
      ("background" . ,(color theme 'bg_1))
      ("border" . ,(color theme 'bg_1))
      ("padding" . "0 3px"))
     (("#window")
      ("color" . ,(color theme 'dim_0))
      ("padding" . "0 10px"))
     ,@(map (cut apply foreground theme <>)
            '(("#idle_inhibitor" dim_0)
              ("#idle_inhibitor.activated" br_yellow)
              ("#network" blue)
              ("#wireplumber" magenta)
              ("#wireplumber.muted" dim_0)
              ("#memory" br_cyan)
              ("#cpu" violet)
              ("#battery" green)
              ("#battery.warning" yellow)
              ("#battery.critical" red)
              ("#disk" yellow)))
     (("#custom-expand")
      ("color" . ,(color theme 'dim_0))
      ("transition" . "color 300ms"))
     ,(foreground theme "#status:hover #custom-expand" 'fg_0)
     (("#clock" "#custom-expand" ,@%styled-status-modules)
      ("padding" . "0 10px")))))

(define (waybar-config-file machine)
  (plain-file "waybar-config"
              (scm->json-string (vector (waybar-config machine)) #:pretty #t)))

(define battery-alert
  (shell-script "battery-alert"
                "notified=\n"
                "while [ -S \"$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY\" ]; do\n"
                "    for battery in /sys/class/power_supply/BAT*; do\n"
                "        capacity=$(cat \"$battery/capacity\")\n"
                "        if [ \"$(cat \"$battery/status\")\" = Discharging ] &&\n"
                "           [ \"$capacity\" -le 15 ]; then\n"
                "            [ -n \"$notified\" ] ||\n"
                "                " libnotify "/bin/notify-send -u critical"
                " \"Akku fast leer\" \"Noch $capacity %\"\n"
                "            notified=1\n"
                "        else\n"
                "            notified=\n"
                "        fi\n"
                "    done\n"
                "    sleep 60\n"
                "done\n"))

(define (waybar-services machine)
  (list (apply home-packages waybar
               (if (machine-audio? machine) (list wireplumber) '()))
        (simple-service 'waybar-config
                        home-xdg-configuration-files-service-type
                        `(("waybar/config" ,(waybar-config-file machine))
                          ("waybar/style.css"
                           ,(waybar-style (machine-theme machine)))))
        (apply wm-extensions (machine-wm machine) 'waybar-autostart
               (wm-autostart (file-append waybar "/bin/waybar"))
               (if (machine-mobile? machine)
                   (list (wm-autostart battery-alert))
                   '()))))
