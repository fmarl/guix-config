(define-module (my home gnupg)
  #:use-module (guix gexp)
  #:use-module (gnu services)
  #:use-module (gnu packages gnupg)
  #:use-module (gnu home services gnupg)
  #:export (%gpg-services))

(define (gpg-agent-service)
  (service home-gpg-agent-service-type
           (home-gpg-agent-configuration
            (pinentry-program
             (file-append pinentry "/bin/pinentry-curses"))
	    (extra-content "allow-emacs-pinentry"))))

(define %gpg-services
  (list (gpg-agent-service)))
