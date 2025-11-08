(define-module (my home lf)
  #:use-module (guix gexp)
  #:use-module (gnu packages)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:export (
	    %lf-services
	    %lf-packages))

(define %lf-services
  (list (simple-service 'lf-config
			home-files-service-type
			`((".config/lf/lfrc"
			   ,(local-file "../../dotfiles/.config/lf/lfrc")))
			)))

(define %lf-packages
  (specifications->packages
   (list "lf")))
