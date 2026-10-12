;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2025, 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (hosts workstation home)
  #:use-module (common home base)
  #:use-module (common machines)
  #:export (%home))

(define %machine
  (lookup-machine 'workstation))

(define %home
  (base-home-environment %machine
                         #:ssh-clients '(thinkpad)
                         #:services (append (desktop-services %machine)
                                            (secrets-services %machine))))

%home
