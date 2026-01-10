(define-module (my home mail)
  #:use-module (guix gexp)
  #:use-module (gnu packages)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:export (%mail-packages %mail-services))

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


(define %mail-packages
  (specifications->packages
   (list
    "isync"
    "msmtp"
    "mu"
    "age")))

(define %mail-services
  (list isync-service msmtp-service))
