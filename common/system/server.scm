;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common system server)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (common system networking)
  #:export (%server-services))

(define %server-services
  (cons ssh-server-service
        (map (lambda (tty)
               (service mingetty-service-type
                        (mingetty-configuration (tty tty))))
             '("tty1" "tty2" "tty3"))))
