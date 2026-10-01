(define-module (hosts workstation home)
  #:use-module (guix gexp)
  #:use-module (common home base)
  #:export (%home))

(define %home
  (base-home-environment 'workstation
                         #:mail? #t
                         #:authorized-keys (list (local-file "pubkeys/0.pub"))))

%home
