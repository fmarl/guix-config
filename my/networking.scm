(define-module (my networking)
  #:use-module (guix gexp)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu services networking)
  #:export (make-network make-static-network-service network-manager-services
                         make-firewall-service))

(define* (make-network #:key (nic-config network-manager-services)
                       (firewall (make-firewall-service)))
  (append nic-config firewall
          (list (service static-networking-service-type
                         (list %loopback-static-networking)))))

(define* (make-static-network-service nic ip gateway #:key (name-servers '("1.1.1.1")))
  (list (service static-networking-service-type
                 (list (static-networking (addresses (list (network-address (device nic)
                                                                            (value ip))))
                                          (routes (list (network-route (destination "default")
                                                                       (gateway gateway))))
                                          (name-servers name-servers))))))

(define network-manager-services
  (list (service network-manager-service-type)
        (service wpa-supplicant-service-type)))

(define* (make-firewall-service #:key (allow-ssh? #f))
  (list (service nftables-service-type
                 (nftables-configuration (ruleset (plain-file "nftables.conf"
                                                              (format #f
                                                               "# A simple and safe firewall (based on %default-nftables-ruleset)
table inet filter {
  chain input {
    type filter hook input priority 0; policy drop;

    # early drop of invalid connections
    ct state invalid drop

    # allow established/related connections
    ct state { established, related } accept

    # allow from loopback
    iif lo accept
    # drop connections to lo not coming from lo
    iif != lo ip daddr 127.0.0.1/8 drop
    iif != lo ip6 daddr ::1/128 drop

    ~a

    # reject everything else
    reject with icmpx type port-unreachable
  }
  chain output {
    type filter hook output priority 0; policy accept;
  }
}
"
                                                               (if allow-ssh?
                                                                "tcp dport ssh accept"
                                                                ""))))))))
