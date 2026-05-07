(define-module (common home mail)
  #:use-module (guix gexp)
  #:use-module (gnu packages)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:use-module (common home helpers)
  #:export (%mail-services))

(define %mail-services
  (list (home-packages "mbsync-locked" "msmtp-locked")
	(simple-service 'mail-config
			home-files-service-type
			`((".mbsyncrc"
			   ,(local-file "../../dotfiles/.mbsyncrc" "mbsyncrc"))
			  (".msmtprc"
			   ,(local-file "../../dotfiles/.msmtprc" "msmtprc"))))))
