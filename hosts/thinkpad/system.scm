;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2025, 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (hosts thinkpad system)
  #:use-module (gnu)
  #:use-module (nongnu packages linux)
  #:use-module (sagittarius services vpn)
  #:use-module (guix-impermanence services)
  #:use-module (common machines)
  #:use-module (common system base)
  #:use-module (hosts thinkpad hardware)
  #:export (%system))

(define %machine
  (lookup-machine 'thinkpad))

(define %system
  (base-operating-system
   %machine
   #:kernel-config (local-file "defconfig")
   #:initrd-modules (list "nvme" "usbhid" "hid-generic" "dm-crypt")
   ;; i915 disables runtime PM without its DMC firmware
   #:firmware (cons* i915-firmware
                     ibt-hw-firmware
                     iwlwifi-firmware
                     %base-firmware)
   #:guix-daemon-options (list "--max-jobs=2")
   #:mapped-devices %mapped-devices
   #:file-systems %file-systems
   #:services (list (simple-service 'mullvad-state
                                    persisted-directories-service-type
                                    '(("/etc/mullvad-vpn" #o700)))
                    (service mullvad-service-type))))

%system
