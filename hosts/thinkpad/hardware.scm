;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (hosts thinkpad hardware)
  #:use-module (gnu)
  #:use-module (common system filesystem)
  #:use-module (hosts thinkpad disk)
  #:export (%mapped-devices %file-systems))

(define %mapped-devices
  (list (mapped-device
          (source (uuid %luks-uuid))
          (target "guix-root")
          (type luks-device-mapping)
          (arguments (list #:allow-discards? #t)))))

(define %file-systems
  (impermanent-file-systems "/dev/mapper/guix-root"
                            "compress=zstd:3,discard=async"
                            #:esp %esp-uuid
                            #:dependencies %mapped-devices))
