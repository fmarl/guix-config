(define-module (common home waybar)
  #:use-module (guix gexp)
  #:use-module (json)
  #:use-module (srfi srfi-1)
  #:use-module (gnu packages)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:use-module (common home helpers)
  #:use-module (common home colors)
  #:export (waybar-services))


(define (segment module)
  (list "custom/left-arrow-dark" module "custom/left-arrow-light"))

(define (arrow glyph)
  `(("format" . ,glyph)
    ("tooltip" . #f)))

(define calendar-tooltip
  "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>")

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
	 (append (append-map segment
			     (list "idle_inhibitor"
				   "network"
				   "wireplumber"
				   "memory"
				   "cpu"
				   (if mobile? "battery" "disk")))
		 (list "custom/left-arrow-dark" "tray"))))

    ("custom/left-arrow-dark" . ,(arrow "\ue0b2"))
    ("custom/left-arrow-light" . ,(arrow "\ue0b2"))
    ("custom/right-arrow-dark" . ,(arrow "\ue0b0"))
    ("custom/right-arrow-light" . ,(arrow "\ue0b0"))

    ("niri/window" . (("max-length" . 60)))

    ("clock#1" . (("format" . "{:%a}")
		  ("tooltip-format" . ,calendar-tooltip)))
    ("clock#2" . (("format" . "{:%H:%M}")
		  ("tooltip-format" . ,calendar-tooltip)))
    ("clock#3" . (("format" . "{:%d.%m}")
		  ("tooltip-format" . ,calendar-tooltip)))

    ("idle_inhibitor" . (("format" . "{icon}")
			 ("format-icons" . (("activated" . "\uf06e")
					    ("deactivated" . "\uf070")))))

    ("wireplumber" . (("format" . "{volume}% {icon}")
		      ("format-muted" . "\uf6a9")
		      ("format-icons" . #("\uf026" "\uf027" "\uf028"))
		      ("on-click" . "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")))

    ("disk" . (("interval" . 5)
	       ("format" . "Disk {percentage_used:2}%")
	       ("path" . "/")))

    ("tray" . (("spacing" . 10)))
    ("cpu" . (("format" . "{usage}% \uf2db")))
    ("memory" . (("format" . "{}% \uf538")))

    ("battery" . (("states" . (("warning" . 30)
			       ("critical" . 15)))
		  ("format" . "{capacity}% {icon}")
		  ("format-charging" . "{capacity}% \uf5e7")
		  ("format-plugged" . "{capacity}% \uf1e6")
		  ("format-alt" . "{time} {icon}")
		  ("format-icons" . #("\uf244" "\uf243" "\uf242" "\uf241" "\uf240"))))

    ("network" . (("format-wifi" . "({signalStrength}%) \uf1eb")
		  ("format-ethernet" . "Ethernet \uf6ff")
		  ("format-linked" . "Ethernet (No IP) \uf6ff")
		  ("format-disconnected" . "Disconnected \uf057")
		  ("format-alt" . "{bandwidthDownBits}/{bandwidthUpBits}")))))

(define (waybar-style)
  (define (c name) (color name))
  (string-append "* {
  font-size: 18px;
  font-family: \"Aporetic Sans Mono\";
}

window#waybar {
  background: " (c 'bg_0) ";
  color: " (c 'fg_0) ";
}

#custom-right-arrow-dark,
#custom-left-arrow-dark {
  color: " (c 'bg_1) ";
}

#custom-right-arrow-light,
#custom-left-arrow-light {
  color: " (c 'bg_0) ";
  background: " (c 'bg_1) ";
}

#workspaces,
#clock.1,
#clock.2,
#clock.3,
#idle_inhibitor,
#network,
#wireplumber,
#memory,
#cpu,
#battery,
#disk,
#tray {
  background: " (c 'bg_1) ";
}

#workspaces button {
  padding: 0 2px;
  color: " (c 'fg_0) ";
}

#workspaces button.active,
#workspaces button.focused {
  color: " (c 'br_blue) ";
}

#workspaces button.urgent {
  color: " (c 'red) ";
}

#workspaces button:hover {
  box-shadow: inherit;
  text-shadow: inherit;
  background: " (c 'bg_1) ";
  border: " (c 'bg_1) ";
  padding: 0 3px;
}

#window {
  color: " (c 'dim_0) ";
  padding: 0 10px;
}

#idle_inhibitor {
  color: " (c 'dim_0) ";
}

#idle_inhibitor.activated {
  color: " (c 'br_yellow) ";
}

#network {
  color: " (c 'blue) ";
}

#wireplumber {
  color: " (c 'magenta) ";
}

#wireplumber.muted {
  color: " (c 'dim_0) ";
}

#memory {
  color: " (c 'br_cyan) ";
}

#cpu {
  color: " (c 'violet) ";
}

#battery {
  color: " (c 'green) ";
}

#battery.warning {
  color: " (c 'yellow) ";
}

#battery.critical {
  color: " (c 'red) ";
}

#disk {
  color: " (c 'yellow) ";
}

#clock,
#idle_inhibitor,
#network,
#wireplumber,
#memory,
#cpu,
#battery,
#disk {
  padding: 0 10px;
}
"))

(define* (waybar-services #:key mobile?)
  (list (home-packages "waybar" "wireplumber")
	(simple-service 'waybar-config
			home-xdg-configuration-files-service-type
			`(("waybar/config"
			   ,(plain-file "waybar-config"
					(scm->json-string
					 (vector (waybar-config #:mobile? mobile?))
					 #:pretty #t)))
			  ("waybar/style.css"
			   ,(plain-file "waybar-style.css" (waybar-style)))))))
