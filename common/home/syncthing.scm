;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common home syncthing)
  #:use-module (gnu home services syncthing)
  #:use-module (gnu services)
  #:use-module (common machines)
  #:use-module (common syncthing)
  #:use-module (ice-9 match)
  #:export (syncthing-services))

(define (syncthing-services machine)
  (match (machine-syncthing-hub machine)
    (#f '())
    (hub
     (let ((peer (syncthing-peer (lookup-machine hub) #:dial? #t)))
       (list (service home-syncthing-service-type
                      (for-home
                       (syncthing-configuration
                        (config-file
                         (synced-folders-config "~" (list peer)))))))))))
