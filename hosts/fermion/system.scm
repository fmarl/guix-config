(define-module (hosts fermion system)
  #:use-module (gnu)
  #:use-module (nongnu packages linux)
  #:use-module (common machines)
  #:use-module (common system base)
  #:use-module (common system networking)
  #:use-module (common system server)
  #:use-module (hosts fermion hardware)
  #:export (%system))

(define %machine
  (lookup-machine 'fermion))

(define %system
  (base-operating-system %machine
                         #:firmware (list linux-firmware)
                         #:mapped-devices %mapped-devices
                         #:file-systems %file-systems
                         #:services (append %server-services
                                            (network-services %machine
                                                              #:open-tcp-ports
                                                              (list "ssh")))))

%system
