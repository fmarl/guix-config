(define-module (common home mail)
  #:use-module (guix gexp)
  #:use-module (gnu packages)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:use-module (common home helpers)
  #:export (%mail-services))

(define isync-service
  (simple-service 'isync-config
		  home-files-service-type
		  `((".mbsyncrc"
		     ,(local-file "../../dotfiles/.mbsyncrc" "mbsyncrc")))))

(define msmtp-service
  (simple-service 'msmtp-config
		  home-files-service-type
		  `((".msmtprc"
		     ,(local-file "../../dotfiles/.msmtprc" "msmtprc")))))


(define %mail-services
  (list (home-packages "isync" "msmtp")
	isync-service
	msmtp-service))
