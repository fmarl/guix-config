(define-module (common home swayidle)
  #:use-module (guix gexp)
  #:use-module (gnu packages window-management)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages zig-xyz)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:use-module (common home helpers)
  #:use-module (common home niri)
  #:export (%swayidle-services))

(define lock-program
  (shell-script "lock-screen"
		procps "/bin/pgrep -x waylock || "
		"exec " waylock "/bin/waylock -fork-on-lock\n"))

(define swayidle-config
  (mixed-text-file "swayidle-config"
		   "timeout 600 '" lock-program "'\n"
		   "timeout 900 '" niri "/bin/niri msg action power-off-monitors'\n"))

(define %swayidle-services
  (list (home-packages swayidle waylock)
	(simple-service 'swayidle-config
			home-xdg-configuration-files-service-type
			`(("swayidle/config" ,swayidle-config)))
	(simple-service 'swayidle-niri
			home-niri-service-type
			(list (niri-spawn-at-startup
			       (file-append swayidle "/bin/swayidle") "-w")
			      (niri-bind "Super+Alt+L" (niri-spawn lock-program)
					 #:title "Lock the Screen")))))
