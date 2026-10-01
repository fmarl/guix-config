(define-module (common machines)
  #:export (%machines
            machine-ref
            machine-address))

(define %machines
  '((workstation (address . "192.168.0.200")
                 (interface . "enp5s0")
                 (gateway . "192.168.0.1"))
    (boson (address . "192.168.0.201"))
    (thinkpad)))

(define (machine-ref name key)
  (assq-ref (or (assq-ref %machines name)
                (error "unknown machine" name))
            key))

(define (machine-address name)
  (machine-ref name 'address))
