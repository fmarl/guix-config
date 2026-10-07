;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2025, 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (hosts thinkpad system)
  #:use-module (gnu)
  #:use-module (gnu services desktop)
  #:use-module (nongnu packages linux)
  #:use-module (sagittarius services vpn)
  #:use-module (common system acpi)
  #:use-module (common system base)
  #:use-module (common system desktop)
  #:use-module (common system filesystem)
  #:use-module (common system kernel)
  #:use-module (common system networking)
  #:use-module (hosts thinkpad hardware)
  #:export (%system))

(define %system
  (operating-system
    (inherit %base-os)
    (host-name "thinkpad")
    (kernel (linux-with-defconfig (local-file "defconfig")))
    (initrd-modules (list "nvme" "usbhid" "hid-generic" "dm-crypt"))
    ;; i915 disables runtime PM without its DMC firmware
    (firmware (cons* i915-firmware ibt-hw-firmware iwlwifi-firmware
                     %base-firmware))

    (services
     (append (desktop-session 'thinkpad)
             (network-services)
             (list (service bluetooth-service-type)
                   (service acpid-service-type)
                   (service upower-service-type)
                   (service mullvad-service-type))
             (operating-system-user-services %base-os)))

    (mapped-devices %mapped-devices)
    (file-systems (append %file-systems %hardened-base-file-systems))))

%system
