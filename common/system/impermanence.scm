;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common system impermanence)
  #:use-module ((guix-impermanence file-systems)
                #:prefix impermanence:)
  #:use-module ((guix-impermanence services)
                #:prefix impermanence:)
  #:export (impermanence-services))

(define (impermanence-services file-systems users)
  (if (impermanence:impermanent-file-systems? file-systems)
      (impermanence:impermanence-services users)
      '()))
