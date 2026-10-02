(define-module (hosts default home)
  #:use-module (common home base)
  #:export (%home))

(define %home
  (base-home-environment 'default))

%home
