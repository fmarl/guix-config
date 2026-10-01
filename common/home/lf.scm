(define-module (common home lf)
  #:use-module (guix gexp)
  #:use-module (gnu packages)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:use-module (common home helpers)
  #:export (%lf-services))

(define %lf-services
  (list (home-packages "lf" "bat" "file")
	(simple-service 'lf-config
			home-xdg-configuration-files-service-type
			`(("lf/lfrc" ,(local-file "../../dotfiles/.config/lf/lfrc"))
			  ("lf/preview" ,(local-file "../../dotfiles/.config/lf/preview"
						     #:recursive? #t))))))
