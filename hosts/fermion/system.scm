;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (hosts fermion system)
  #:use-module (gnu)
  #:use-module (nongnu packages linux)
  #:use-module (common machines)
  #:use-module (common syncthing)
  #:use-module (common system base)
  #:use-module (common system networking)
  #:use-module (common system server)
  #:use-module (common system syncthing)
  #:use-module (hosts fermion hardware)
  #:export (%system))

(define %machine
  (lookup-machine 'fermion))

(define %system
  (base-operating-system %machine
                         #:kernel-arguments (list "net.ifnames=0")
                         #:firmware (list linux-firmware)
                         #:mapped-devices %mapped-devices
                         #:file-systems %file-systems
                         #:persisted-directories `((,%syncthing-state-directory
                                                    #o700))
                         #:snapshot-directories (list %sync-directory)
                         #:services (append %server-services
                                            (network-services %machine
                                                              #:open-tcp-ports
                                                              (list "ssh"
                                                               %syncthing-port))
                                            (syncthing-server-services
                                             %sync-directory
                                             '(workstation thinkpad)))))

%system
