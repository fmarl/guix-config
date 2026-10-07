;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2025, 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (hosts thinkpad home)
  #:use-module (common home base)
  #:use-module (sagittarius packages vpn)
  #:export (%home))

(define %home
  (base-home-environment 'thinkpad
                         #:packages (list mullvad-vpn-desktop)
                         #:services (append (desktop-services 'thinkpad #:mobile? #t)
                                            (secrets-services 'thinkpad))))

%home
