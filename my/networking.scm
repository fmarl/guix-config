(define-module (my networking)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu services networking))

(define-public (make-static-network nic ip)
  (service static-networking-service-type
           (list (static-networking
                  (addresses
                   (list (network-address
                          (device nic)
                          (value ip))))
                  (routes
                   (list (network-route
                          (destination "default")
                          (gateway "192.168.0.1"))))
                  (name-servers '("1.1.1.1"))))))

(define-public network-manager-service
  (list
   (service network-manager-service-type)
   (service wpa-supplicant-service-type)))
