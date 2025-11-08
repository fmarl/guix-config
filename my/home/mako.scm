(define-module (my home mako)
  #:use-module (guix gexp)
  #:use-module (gnu packages)
  #:use-module (gnu packages wm)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:use-module (gnu home services shepherd)
  #:export (%mako-services))

(define %mako-services
  (list
   (simple-service 'mako-config home-files-service-type
		   `((".config/mako/config"
		      ,(local-file "../../dotfiles/.config/mako/config")))
		   )
   (simple-service 'mako home-shepherd-service-type
		   (list (shepherd-service
			  (provision '(mako))
			  (start
			   #~(let* ((wl-display (getenv "WAYLAND_DISPLAY"))
				    (xdg-runtime-dir (getenv "XDG_RUNTIME_DIR")))
			       (if (not wl-display)
				   (begin
				     (format (current-error-port)
					     "ERROR: WAYLAND_DISPLAY is not set\n")
				     (exit 1))
				   
				   (begin
				     (format #t "WAYLAND_DISPLAY: ~a\n" wl-display)
				     (format #t "XDG_RUNTIME_DIR: ~a\n" xdg-runtime-dir)
				     (make-forkexec-constructor
				      (list #$(file-append mako "/bin/mako"))
				      #:log-file (string-append (getenv "HOME") "/.local/state/shepherd/mako.log"))))))
			  
			  (stop #~(make-system-destructor
				   #$(file-append mako "/bin/mako")))
			  
			  (documentation (string-append "Wayland notification services")))))))
