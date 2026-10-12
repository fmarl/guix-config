;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2025, 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (hosts workstation system)
  #:use-module (gnu)
  #:use-module (gnu services linux)
  #:use-module (nongnu packages linux)
  #:use-module (common machines)
  #:use-module (common system base)
  #:use-module (common system networking)
  #:use-module (hosts workstation hardware)
  #:export (%system))

(define %machine
  (lookup-machine 'workstation))

(define %system
  (base-operating-system %machine
                         #:kernel-config (local-file "defconfig")
                         #:initrd-modules (list "nvme" "usbhid" "hid-generic")
                         #:kernel-arguments (list
                                             "it87.ignore_resource_conflict=1")
                         #:firmware (list amdgpu-firmware realtek-firmware)
                         #:guix-daemon-options (list "--max-jobs=4")
                         #:mapped-devices %mapped-devices
                         #:file-systems %file-systems
                         #:services (append (network-services %machine
                                                              #:open-tcp-ports
                                                              (list "ssh"))
                                            (list (simple-service 'sensors
                                                   kernel-module-loader-service-type
                                                   (list "it87"))
                                                  ssh-server-service))))

%system
