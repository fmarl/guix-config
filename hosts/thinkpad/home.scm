;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2025, 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (hosts thinkpad home)
  #:use-module (common home base)
  #:use-module (common machines)
  #:use-module (sagittarius packages vpn)
  #:export (%home))

(define %machine (lookup-machine 'thinkpad))

(define %home
  (base-home-environment %machine
                         #:packages (list mullvad-vpn-desktop)
                         #:services (append (desktop-services %machine)
                                            (secrets-services %machine))))

%home
