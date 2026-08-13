;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (hosts default home)
  #:use-module (common home base)
  #:export (%home))

(define %home
  (base-home-environment 'default))

%home
