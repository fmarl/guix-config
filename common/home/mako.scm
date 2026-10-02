(define-module (common home mako)
  #:use-module (guix gexp)
  #:use-module (gnu packages)
  #:use-module (gnu packages window-management)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:use-module (common home helpers)
  #:use-module (common home colors)
  #:use-module (common home niri)
  #:export (%mako-services))

(define mako-config
  (plain-file "mako-config"
	      (string-append "background-color=" (color 'bg_2) "\n"
			     "border-color=" (color 'bg_1) "\n"
			     "border-radius=12\n"
			     "progress-color=" (color 'cyan) "\n")))

(define %mako-services
  (list (home-packages "mako" "libnotify")
	(simple-service 'mako-config
			home-xdg-configuration-files-service-type
			`(("mako/config" ,mako-config)))
	(simple-service 'mako-autostart
			home-niri-service-type
			(list (niri-spawn-at-startup (file-append mako "/bin/mako"))))))
