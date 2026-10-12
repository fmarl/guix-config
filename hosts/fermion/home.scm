(define-module (hosts fermion home)
  #:use-module (common home base)
  #:use-module (common machines)
  #:export (%home))

(define %machine
  (lookup-machine 'fermion))

(define %home
  (base-home-environment %machine
                         #:ssh-clients '(thinkpad workstation)))

%home
