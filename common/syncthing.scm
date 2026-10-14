;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common syncthing)
  #:use-module (gnu services syncthing)
  #:use-module (common machines)
  #:export (%syncthing-port %syncthing-temporary-files
                           syncthing-peer
                           synced-folders-config))

(define %syncthing-port
  "22000")

(define %syncthing-temporary-files
  '(".syncthing.*.tmp"))

(define %synced-folders
  '("Pictures" "Documents" "Videos" "Music" "Org"))

(define* (syncthing-peer machine
                         #:key dial?)
  (syncthing-device (id (machine-syncthing-id machine))
                    (name (symbol->string (machine-name machine)))
                    (addresses (if dial?
                                   (list (string-append "tcp://"
                                                        (machine-address
                                                         machine) ":"
                                                        %syncthing-port))
                                   '("dynamic")))))

(define (synced-folders-config directory peers)
  (syncthing-config-file (folders (map (lambda (name)
                                         (syncthing-folder (id (string-downcase
                                                                name))
                                                           (label name)
                                                           (path (string-append
                                                                  directory
                                                                  "/" name))
                                                           (devices peers)))
                                       %synced-folders))
                         (global-announce-enabled? #f)
                         (local-announce-enabled? #f)
                         (relays-enabled? #f)
                         (nat-enabled? #f)
                         (start-browser? #f)
                         (usage-reporting-accepted -1)
                         (crash-reporting-enabled? #f)
                         (auto-upgrade-interval-hours 0)))
