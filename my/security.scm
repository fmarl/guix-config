(define-module (my security)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu services security-token)
  #:use-module (gnu packages security-token)
  #:export (%security-services))

(define %security-services
  (list
   (service pcscd-service-type)
   
   ;; fido2 (Yubikey etc)
   (udev-rules-service 'fido2 libfido2 #:groups '("plugdev"))))
