;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common home ssh)
  #:use-module (guix gexp)
  #:use-module (gnu home services)
  #:use-module (gnu home services ssh)
  #:use-module (gnu services)
  #:use-module (common files)
  #:use-module (common home bemenu)
  #:use-module (common machines)
  #:use-module (common users)
  #:use-module (srfi srfi-1)
  #:export (host-file
            ssh-services))

(define (host-file host name)
  (config-file (string-append "hosts/" (symbol->string host) "/" name)))

(define %identity-files
  '("id_ed25519_sk_18067519" "id_ed25519_sk_backup"))

(define (identity-file name)
  (config-file (string-append "dotfiles/.ssh/" name)))

(define %git-hosts
  '("codeberg.org" "github.com"))

(define* (ssh-host name host-name user #:key (server-alive-count-max 2))
  (openssh-host
   (name name)
   (host-name host-name)
   (user user)
   (extra-content (string-append "  ServerAliveCountMax "
                                 (number->string server-alive-count-max)
                                 "\n"))))

(define (git-host host-name)
  (ssh-host host-name host-name "git"
            #:server-alive-count-max 1))

(define (lan-hosts self)
  "SSH hosts for all machines with a fixed address, except SELF."
  (filter-map (lambda (machine)
                (and (not (eq? (machine-name machine) self))
                     (ssh-host (symbol->string (machine-name machine))
                               (machine-address machine)
                               (user-name %user))))
              %addressed-machines))

(define drop-in-host
  (openssh-host
   (match-criteria "all")
   (extra-content "  Include config.d/*\n")))

(define default-host
  (openssh-host
   (name "*")
   (extra-content (string-append
                   (string-concatenate
                    (map (lambda (identity)
                           (string-append "  IdentityFile ~/.ssh/" identity
                                          "\n"))
                         %identity-files))
                   "  IdentitiesOnly yes\n"
                   "  HashKnownHosts yes\n"
                   "  ServerAliveInterval 30\n"))))

(define (ssh-services machine)
  "Other services can add configuration as files in ~/.ssh/config.d/."
  (append
   (list (service home-openssh-service-type
                  (home-openssh-configuration
                   (hosts (cons drop-in-host
                                (append (map git-host %git-hosts)
                                        (lan-hosts (machine-name machine))
                                        (list default-host))))
                   (authorized-keys
                    (and (pair? (machine-ssh-clients machine))
                         (map (lambda (identity)
                                (identity-file
                                 (string-append identity ".pub")))
                              %identity-files)))))
         (simple-service 'identity-files home-files-service-type
                         (map (lambda (identity)
                                (list (string-append ".ssh/" identity)
                                      (identity-file identity)))
                              %identity-files)))
   ;; Without a terminal, ssh asks for the FIDO2 PIN through SSH_ASKPASS.
   (if (machine-wm machine)
       (list (simple-service 'ssh-askpass
                             home-environment-variables-service-type
                             `(("SSH_ASKPASS"
                                . ,(bemenu-askpass (machine-theme machine))))))
       '())))
