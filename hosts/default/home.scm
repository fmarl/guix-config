;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (hosts default home)
  #:use-module (common home base)
  #:use-module (common machines)
  #:export (%home))

(define %machine (lookup-machine 'default))

(define %home
  (base-home-environment %machine))

%home
