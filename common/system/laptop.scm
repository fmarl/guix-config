;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common system laptop)
  #:use-module (gnu services)
  #:use-module (gnu services desktop)
  #:use-module (gnu services pm)
  #:use-module (guix-impermanence services)
  #:use-module (common system acpi)
  #:export (%laptop-services))

(define %laptop-services
  (list (simple-service 'laptop-state persisted-directories-service-type
                        '(("/var/lib/bluetooth" #o700)
                          ("/var/lib/power-profiles-daemon" #o755)))
        (service bluetooth-service-type)
        (service acpid-service-type)
        (service upower-service-type)
        (service power-profiles-daemon-service-type)))
