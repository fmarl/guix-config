(define-module (common system networking)
  #:use-module (guix gexp)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu services networking)
  #:use-module (ice-9 match)
  #:use-module (common machines)
  #:export (network-services))

(define (static-network-services machine)
  (list (service static-networking-service-type
                 (list (static-networking
                        (addresses (list (network-address
                                          (device (machine-ref machine 'interface))
                                          (value (string-append
                                                  (machine-address machine) "/24")))))
                        (routes (list (network-route
                                       (destination "default")
                                       (gateway (machine-ref machine 'gateway)))))
                        (name-servers '("1.1.1.1" "8.8.8.8")))))))

(define nm-mac-randomization-conf
  (plain-file "mac-randomization.conf"
              "[device]
wifi.scan-rand-mac-address=yes

[connection]
wifi.cloned-mac-address=random
"))

(define network-manager-services
  (list (service network-manager-service-type
                 (network-manager-configuration
                  (extra-configuration-files
                   `(("mac-randomization.conf" ,nm-mac-randomization-conf)))))
        (service wpa-supplicant-service-type)))

(define (firewall-service allow-ssh?)
  (service nftables-service-type
           (nftables-configuration
            (ruleset (plain-file "nftables.conf"
                                 (string-append "\
# A simple and safe firewall (based on %default-nftables-ruleset)
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
"
                                                (if allow-ssh?
                                                    "\n    tcp dport ssh accept\n"
                                                    "")
                                                "
    # reject everything else
    reject with icmpx type port-unreachable
  }
  chain output {
    type filter hook output priority 0; policy accept;
  }
}
"))))))

(define lan-hosts-service
  (simple-service 'lan-hosts hosts-service-type
                  (map (match-lambda
                         ((name . address)
                          (host address (symbol->string name))))
                       (machine-addresses))))

(define* (network-services #:key static allow-ssh?)
  "Return the network services: a static address for the machine STATIC from
%machines, NetworkManager otherwise, and a firewall."
  (append (if static
              (static-network-services static)
              network-manager-services)
          (list (firewall-service allow-ssh?)
                (service static-networking-service-type
                         (list %loopback-static-networking))
                lan-hosts-service)))
