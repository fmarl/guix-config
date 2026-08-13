;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2025, 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (hosts workstation home)
  #:use-module (guix gexp)
  #:use-module (common home base)
  #:export (%home))

(define %home
  (base-home-environment 'workstation
                         #:authorized-keys (list (local-file "../thinkpad/ssh.pub"))
                         #:services (append (desktop-services 'workstation #:audio? #f)
                                            %mail-services
                                            (secrets-services 'workstation))))

%home
