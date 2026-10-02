(define-module (common machines)
  #:use-module (srfi srfi-1)
  #:use-module (ice-9 match)
  #:export (%machines
            machine-ref
            machine-address
            machine-addresses))

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

(define (machine-addresses)
  "Return (NAME . ADDRESS) for every machine with a fixed address."
  (filter-map (match-lambda
                ((name . properties)
                 (let ((address (assq-ref properties 'address)))
                   (and address (cons name address)))))
              %machines))
