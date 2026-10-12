;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common home ssh)
  #:use-module (guix gexp)
  #:use-module (gnu home services ssh)
  #:use-module (gnu services)
  #:use-module (common machines)
  #:use-module (common users)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-26)
  #:export (%ssh-public-key-file %ssh-host-names host-file ssh-services))

(define (host-file host name)
  (local-file (assume-source-relative-file-name (string-append "../../hosts/"
                                                               (symbol->string
                                                                host) "/" name))))

(define %ssh-public-key-file
  ".ssh/id_ed25519.pub")

(define %git-hosts
  '("codeberg.org" "github.com"))

(define %ssh-host-names
  (append %git-hosts
          (map (compose symbol->string machine-name) %addressed-machines)))

(define* (ssh-host name host-name user
                   #:key (server-alive-count-max 2))
  (openssh-host (name name)
                (host-name host-name)
                (user user)
                (extra-content (string-append "  ServerAliveCountMax "
                                              (number->string
                                               server-alive-count-max) "\n"))))

(define (git-host host-name)
  (ssh-host host-name host-name "git"
            #:server-alive-count-max 1))

(define (lan-hosts self)
  "SSH hosts for all machines with a fixed address, except SELF."
  (filter-map (lambda (machine)
                (and (not (eq? (machine-name machine) self))
                     (ssh-host (symbol->string (machine-name machine))
                               (machine-address machine)
                               (user-name %user)))) %addressed-machines))

(define drop-in-host
  (openssh-host (match-criteria "all")
                (extra-content "  Include config.d/*\n")))

(define default-host
  (openssh-host (name "*")
                (extra-content (string-append "  IdentitiesOnly yes\n"
                                              "  HashKnownHosts yes\n"
                                              "  ServerAliveInterval 30\n"))))

(define* (ssh-services self
                       #:key ssh-clients)
  "SSH-CLIENTS are the machines whose ssh.pub may log in.  Other services can
add configuration as files in ~/.ssh/config.d/."
  (list (service home-openssh-service-type
                 (home-openssh-configuration (hosts (cons drop-in-host
                                                          (append (map
                                                                   git-host
                                                                   %git-hosts)
                                                                  (lan-hosts
                                                                   self)
                                                                  (list
                                                                   default-host))))
                                             (authorized-keys (and ssh-clients
                                                               (map (cut
                                                                     host-file
                                                                     <>
                                                                     "ssh.pub")
                                                                ssh-clients)))))
        (service home-ssh-agent-service-type
                 (home-ssh-agent-configuration (extra-options '("-t" "1h30m"))))))
