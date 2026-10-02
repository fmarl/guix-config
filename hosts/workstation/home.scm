(define-module (hosts workstation home)
  #:use-module (guix gexp)
  #:use-module (common home base)
  #:export (%home))

(define %home
  (base-home-environment 'workstation
                         #:authorized-keys (list (local-file "pubkeys/0.pub"))
                         #:services (append (desktop-services)
                                            %mail-services)))

%home
