;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common system networking)
  #:use-module (guix gexp)
  #:use-module (guix records)
  #:use-module (gnu packages linux)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu services dns)
  #:use-module (gnu services networking)
  #:use-module (gnu services ssh)
  #:use-module (guix-impermanence services)
  #:use-module (common machines)
  #:use-module (common users)
  #:use-module (srfi srfi-1)
  #:export (firewall-service-type
            firewall-configuration
            network-services
            ssh-server-services))

(define %lan-prefix-length
  (cadr (string-split %lan-subnet #\/)))

(define (static-network-services machine)
  (unless (and (machine-address machine)
               (machine-gateway machine))
    (error "static networking needs an address and a gateway"
           (machine-name machine)))
  (list (service static-networking-service-type
                 (list (static-networking
                         (addresses
                          (list (network-address
                                  (device (machine-interface machine))
                                  (value (string-append
                                          (machine-address machine)
                                          "/" %lan-prefix-length)))))
                         (routes
                          (list (network-route
                                  (destination "default")
                                  (gateway (machine-gateway machine)))))
                         (name-servers '("127.0.0.1")))))
        dns-over-tls-service))

(define %dns-over-tls-servers
  '("9.9.9.9@853#dns.quad9.net"
    "149.112.112.112@853#dns.quad9.net"
    "194.242.2.2@853#dns.mullvad.net"))

(define dns-over-tls-service
  (service unbound-service-type
           (unbound-configuration
            (forward-zone
             (list (unbound-zone
                    (name ".")
                    (forward-addr %dns-over-tls-servers)
                    (forward-tls-upstream #t)))))))

(define mac-randomization-conf
  (plain-file "mac-randomization.conf" "\
[device]
wifi.scan-rand-mac-address=yes

[connection]
wifi.cloned-mac-address=random
"))

(define network-manager-services
  (list (service network-manager-service-type
                 (network-manager-configuration
                  (extra-configuration-files
                   `(("mac-randomization.conf" ,mac-randomization-conf)))))
        (service wpa-supplicant-service-type)
        (simple-service 'wireless-tools profile-service-type
                        (list iw))
        (udev-rules-service 'crda crda)
        (simple-service 'network-manager-state
                        persisted-directories-service-type
                        '(("/var/lib/NetworkManager" #o700)
                          ("/etc/NetworkManager/system-connections" #o700)))))

(define (nftables-ruleset open-tcp-ports output-rules)
  "Accept replies, loopback, IPv6 essentials, and ping and OPEN-TCP-PORTS from
the LAN.  Reject the rest of the LAN, drop everything else.  Filter outgoing
traffic with OUTPUT-RULES."
  (plain-file "nftables.conf"
              (format #f "\
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
    icmpv6 type { nd-neighbor-solicit, nd-neighbor-advert, nd-router-advert } \
ip6 hoplimit 255 accept
    ip6 saddr fe80::/10 udp sport 547 udp dport 546 accept

    ip saddr ~a icmp type echo-request limit rate 10/second accept
    ip6 saddr fe80::/10 icmpv6 type echo-request limit rate 10/second accept
~a
    # Outside the LAN, stay silent
    ip saddr ~a reject with icmpx type port-unreachable
  }

  chain forward {
    type filter hook forward priority filter; policy drop;
  }

  chain output {
    type filter hook output priority filter; policy accept;
~a  }
}
"
                      %lan-subnet
                      (if (null? open-tcp-ports)
                          ""
                          (format #f
                                  "~%    ip saddr ~a tcp dport { ~a } accept~%"
                                  %lan-subnet
                                  (string-join open-tcp-ports ", ")))
                      %lan-subnet
                      (if (null? output-rules)
                          ""
                          (format #f "~%~{    ~a~%~}" output-rules)))))

(define lan-hosts-service
  (simple-service 'lan-hosts hosts-service-type
                  (map (lambda (machine)
                         (host (machine-address machine)
                               (symbol->string (machine-name machine))))
                       %addressed-machines)))

(define-record-type* <firewall-configuration>
  firewall-configuration make-firewall-configuration
  firewall-configuration?
  (open-tcp-ports firewall-configuration-open-tcp-ports
                  (default '()))
  (output-rules   firewall-configuration-output-rules
                  (default '())))

(define firewall-service-type
  (service-type
    (inherit nftables-service-type)
    (name 'firewall)
    (description
     "Run nftables with a ruleset opening the ports and applying
the output rules of the firewall configuration and its extensions.")
    (compose identity)
    (extend (lambda (config extensions)
              (let ((configs (cons config extensions)))
                (nftables-configuration
                 (ruleset (nftables-ruleset
                           (append-map firewall-configuration-open-tcp-ports
                                       configs)
                           (append-map firewall-configuration-output-rules
                                       configs)))))))
    (default-value (firewall-configuration))))

(define (network-services machine)
  "Return the network services of MACHINE: a static address if it has an
interface, NetworkManager otherwise, and a firewall that other services extend
with the ports and output rules they need."
  (append (if (machine-interface machine)
              (static-network-services machine)
              network-manager-services)
          (list (service firewall-service-type)
                (service static-networking-service-type
                         (list %loopback-static-networking))
                lan-hosts-service)))

(define ssh-server-services
  (list (service openssh-service-type
                 (openssh-configuration
                   (password-authentication? #f)
                   (permit-root-login #f)
                   (challenge-response-authentication? #f)
                   (x11-forwarding? #f)
                   (extra-content (string-append
                                   "AllowUsers " (user-name %user) "\n"
                                   "StreamLocalBindUnlink yes\n"))))
        (simple-service 'ssh-firewall firewall-service-type
                        (firewall-configuration
                          (open-tcp-ports '("ssh"))))))
