(define-module (common home swayidle)
  #:use-module (guix gexp)
  #:use-module (ice-9 match)
  #:use-module (gnu packages window-management)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages zig-xyz)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:use-module (common home helpers)
  #:use-module (common home wm)
  #:export (swayidle-services))

(define lock-program
  (shell-script "lock-screen"
		procps "/bin/pgrep -x waylock || "
		"exec " waylock "/bin/waylock -fork-on-lock\n"))

(define (monitors-off wm)
  (match wm
    ('niri
     (list "'" niri "/bin/niri msg action power-off-monitors'\n"))
    ('nucleotide
     (let ((wlopm (file-append wlopm "/bin/wlopm")))
       (list "'" wlopm " --off \\*' resume '" wlopm " --on \\*'\n")))))

(define (swayidle-config wm)
  (apply mixed-text-file "swayidle-config"
	 "timeout 600 '" lock-program "'\n"
	 "timeout 900 " (monitors-off wm)))

(define (swayidle-services wm)
  (list (home-packages swayidle waylock)
	(simple-service 'swayidle-config
			home-xdg-configuration-files-service-type
			`(("swayidle/config" ,(swayidle-config wm))))
	(wm-extensions wm 'swayidle
		       (wm-autostart (file-append swayidle "/bin/swayidle") "-w")
		       (wm-bind "Super+Alt+L" (list lock-program)
				#:title "Lock the Screen"))))
