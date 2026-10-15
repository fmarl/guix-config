;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common system impermanence)
  #:use-module ((guix-impermanence file-systems) #:prefix impermanence:)
  #:use-module ((guix-impermanence services) #:prefix impermanence:)
  #:export (persisted-file-systems impermanence-services))

(define %persisted-directories
  (append impermanence:%base-persisted-directories
          '(("/var/lib/catch-up" #o755)
            ("/var/lib/bluetooth" #o700)
            ("/var/lib/NetworkManager" #o700)
            ("/etc/NetworkManager/system-connections" #o700))))

(define (persisted-directories file-systems host-directories)
  (cond
    ((impermanence:impermanent-file-systems? file-systems)
     (append %persisted-directories host-directories))
    ((null? host-directories)
     '())
    (else (error "persisted directories need impermanent-file-systems"
                 host-directories))))

(define (persisted-file-systems file-systems host-directories)
  (impermanence:persisted-file-systems (persisted-directories file-systems
                                                              host-directories)))

(define (impermanence-services file-systems host-directories users)
  (if (impermanence:impermanent-file-systems? file-systems)
      (impermanence:impermanence-services (persisted-directories file-systems
                                                                 host-directories)
                                          users)
      '()))
