;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common system networking)
  #:use-module (guix gexp)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu services networking)
  #:use-module (common machines)
  #:export (network-services))

(define (static-network-services machine)
  (list (service static-networking-service-type
                 (list (static-networking
                        (addresses (list (network-address
                                          (device (machine-interface machine))
                                          (value (string-append
                                                  (machine-address machine) "/24")))))
                        (routes (list (network-route
                                       (destination "default")
                                       (gateway (machine-gateway machine)))))
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

(define (nftables-ruleset open-tcp-ports)
  "Drop incoming traffic except replies, loopback, what IPv6 needs to work,
and ping and OPEN-TCP-PORTS from the LAN, which is answered with a reject."
  (plain-file
   "nftables.conf"
   (string-append "\
table inet filter {
  # Reverse path filter, rp_filter only covers IPv4
  chain prerouting {
    type filter hook prerouting priority filter; policy accept;

    icmpv6 type { nd-router-advert, nd-neighbor-solicit } accept
    meta nfproto ipv6 fib saddr . mark . iif oif missing drop
  }

  chain input {
    type filter hook input priority filter; policy drop;

    ct state invalid drop
    ct state { established, related } accept

    iif lo accept
    iif != lo ip daddr 127.0.0.0/8 drop
    iif != lo ip6 daddr ::1 drop

    # Neighbor discovery, SLAAC and DHCPv6, only from the local link
    icmpv6 type { nd-neighbor-solicit, nd-neighbor-advert, nd-router-advert } ip6 hoplimit 255 accept
    ip6 saddr fe80::/10 udp sport 547 udp dport 546 accept

    ip saddr " %lan-subnet " icmp type echo-request limit rate 10/second accept
    ip6 saddr fe80::/10 icmpv6 type echo-request limit rate 10/second accept
"
                  (if (null? open-tcp-ports)
                      ""
                      (string-append "
    ip saddr " %lan-subnet " tcp dport { " (string-join open-tcp-ports ", ")
                                     " } accept
"))
                  "
    # Outside the LAN, stay silent
    ip saddr " %lan-subnet " reject with icmpx type port-unreachable
  }

  chain forward {
    type filter hook forward priority filter; policy drop;
  }

  chain output {
    type filter hook output priority filter; policy accept;
  }
}
")))

(define lan-hosts-service
  (simple-service 'lan-hosts hosts-service-type
                  (map (lambda (machine)
                         (host (machine-address machine)
                               (symbol->string (machine-name machine))))
                       %addressed-machines)))

(define* (network-services #:key static (open-tcp-ports '()))
  "Return the network services: a static address for the machine STATIC,
NetworkManager otherwise, and a firewall allowing OPEN-TCP-PORTS from the
LAN."
  (append (if static
              (static-network-services static)
              network-manager-services)
          (list (service nftables-service-type
                         (nftables-configuration
                          (ruleset (nftables-ruleset open-tcp-ports))))
                (service static-networking-service-type
                         (list %loopback-static-networking))
                lan-hosts-service)))
