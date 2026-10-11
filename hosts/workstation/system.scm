;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2025, 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (hosts workstation system)
  #:use-module (gnu)
  #:use-module (gnu services linux)
  #:use-module (gnu services ssh)
  #:use-module (nongnu packages linux)
  #:use-module (common machines)
  #:use-module (common system base)
  #:use-module (common system desktop)
  #:use-module (common system networking)
  #:use-module (common users)
  #:use-module (hosts workstation hardware)
  #:export (%system))

(define %machine
  (lookup-machine 'workstation))

(define %system
  (base-operating-system %machine
                         #:kernel-config (local-file "defconfig")
                         #:initrd-modules (list "nvme" "usbhid" "hid-generic")
                         #:firmware (list amdgpu-firmware realtek-firmware)
                         #:mapped-devices %mapped-devices
                         #:file-systems %file-systems
                         #:services (append (desktop-session %machine)
                                            (network-services %machine
                                                              #:open-tcp-ports
                                                              (list "ssh"))
                                            (list (simple-service 'sensors
                                                   kernel-module-loader-service-type
                                                   (list "it87"))
                                                  (service
                                                   openssh-service-type
                                                   (openssh-configuration (password-authentication?
                                                                           #f)
                                                                          (permit-root-login
                                                                           #f)
                                                                          (challenge-response-authentication?
                                                                           #f)
                                                                          (x11-forwarding?
                                                                           #f)
                                                                          (extra-content
                                                                           (string-append
                                                                            "AllowUsers "
                                                                            (user-name
                                                                             %user)
                                                                            "\n"
                                                                            "StreamLocalBindUnlink yes\n"))))))))

%system
