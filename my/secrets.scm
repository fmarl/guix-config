(define-module (my secrets)
  #:use-module (gnu services security-token)
  #:export (
	    %secrets-base-services))

(define %secrets-base-services
  (list
   (service pcscd-service-type)))
