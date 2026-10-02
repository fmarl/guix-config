(define-module (common home waybar)
  #:use-module (guix gexp)
  #:use-module (json)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-26)
  #:use-module (gnu packages)
  #:use-module (gnu packages window-management)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:use-module (common home helpers)
  #:use-module (common home colors)
  #:use-module (common home niri)
  #:export (waybar-services))

(define %status-modules
  '("idle_inhibitor" "network" "wireplumber" "memory" "cpu"))

(define (status-modules mobile?)
  (append %status-modules (list (if mobile? "battery" "disk"))))

(define %clock-formats
  '("{:%a}" "{:%H:%M}" "{:%d.%m}"))

(define (clock-name index)
  (string-append "clock#" (number->string index)))

(define (segment module)
  (list "custom/left-arrow-dark" module "custom/left-arrow-light"))

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

(define* (waybar-config #:key mobile?)
  `(("modules-left" . #("niri/workspaces"
                        "custom/right-arrow-dark"
                        "niri/window"))
    ("modules-center" . #("custom/left-arrow-dark"
                          "clock#1"
                          "custom/left-arrow-light"
                          "custom/left-arrow-dark"
                          "clock#2"
                          "custom/right-arrow-dark"
                          "custom/right-arrow-light"
                          "clock#3"
                          "custom/right-arrow-dark"))
    ("modules-right"
     . ,(list->vector
         (append (append-map segment (status-modules mobile?))
                 (list "custom/left-arrow-dark" "tray"))))

    ("custom/left-arrow-dark" . ,(arrow ""))
    ("custom/left-arrow-light" . ,(arrow ""))
    ("custom/right-arrow-dark" . ,(arrow ""))
    ("custom/right-arrow-light" . ,(arrow ""))

    ("niri/window" . (("max-length" . 60)))

    ,@(clock-modules)

    ("idle_inhibitor" . (("format" . "{icon}")
                         ("format-icons" . (("activated" . "")
                                            ("deactivated" . "")))))

    ("wireplumber" . (("format" . "{volume}% {icon}")
                      ("format-muted" . "")
                      ("format-icons" . #("" "" ""))
                      ("on-click" . "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")))

    ("disk" . (("interval" . 5)
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

(define (foreground selector name)
  `((,selector) ("color" . ,(color name))))

(define waybar-style
  (css-file
   "waybar-style.css"
   `((("*")
      ("font-size" . "18px")
      ("font-family" . "\"Aporetic Sans Mono\""))
     (("window#waybar")
      ("background" . ,(color 'bg_0))
      ("color" . ,(color 'fg_0)))
     (("#custom-right-arrow-dark" "#custom-left-arrow-dark")
      ("color" . ,(color 'bg_1)))
     (("#custom-right-arrow-light" "#custom-left-arrow-light")
      ("color" . ,(color 'bg_0))
      ("background" . ,(color 'bg_1)))
     (("#workspaces" ,@%clock-selectors ,@%styled-status-modules "#tray")
      ("background" . ,(color 'bg_1)))
     (("#workspaces button")
      ("padding" . "0 2px")
      ("color" . ,(color 'fg_0)))
     (("#workspaces button.active" "#workspaces button.focused")
      ("color" . ,(color 'br_blue)))
     ,(foreground "#workspaces button.urgent" 'red)
     (("#workspaces button:hover")
      ("box-shadow" . "inherit")
      ("text-shadow" . "inherit")
      ("background" . ,(color 'bg_1))
      ("border" . ,(color 'bg_1))
      ("padding" . "0 3px"))
     (("#window")
      ("color" . ,(color 'dim_0))
      ("padding" . "0 10px"))
     ,@(map (cut apply foreground <>)
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
     (("#clock" ,@%styled-status-modules)
      ("padding" . "0 10px")))))

(define* (waybar-services #:key mobile?)
  (list (home-packages "waybar" "wireplumber")
        (simple-service 'waybar-config
                        home-xdg-configuration-files-service-type
                        `(("waybar/config"
                           ,(plain-file "waybar-config"
                                        (scm->json-string
                                         (vector (waybar-config #:mobile? mobile?))
                                         #:pretty #t)))
                          ("waybar/style.css" ,waybar-style)))
        (simple-service 'waybar-autostart
                        home-niri-service-type
                        (list (niri-spawn-at-startup
                               (file-append waybar "/bin/waybar"))))))
