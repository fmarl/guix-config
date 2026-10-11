;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

;; Print what the scripts need to know about a host, one "KEY VALUE..." per
;; line.  Run with: guix repl -- scripts/host-info.scm layout|system HOST

(use-modules (gnu system)
             (gnu system accounts)
             (gnu system file-systems)
             (gnu system mapped-devices)
             (gnu system uuid)
             (common system filesystem)
             (ice-9 match)
             (srfi srfi-1)
             (srfi srfi-26))

(define (fact key . values)
  (format #t "~a~{ ~a~}~%" key values))

(define (device-uuid device)
  (and (uuid? device)
       (uuid->string device)))

(define (host-variable host module name)
  (module-ref (resolve-interface `(hosts ,(string->symbol host)
                                         ,module)) name))

(define (layout-facts file-systems mapped-devices)
  (when (impermanent-file-systems? file-systems)
    (fact 'persist %persist))
  (for-each (match-lambda
              ((name . mount-point) (fact 'subvolume name
                                          (or mount-point "-"))))
            (btrfs-subvolumes file-systems))
  (for-each (lambda (device)
              (and=> (device-uuid (mapped-device-source device))
                     (lambda (uuid)
                       (fact 'luks uuid
                             (first (mapped-device-targets device))))))
            mapped-devices)
  (for-each (lambda (fs)
              (when (string=? (file-system-mount-point fs) "/boot/efi")
                (fact 'esp
                      (device-uuid (file-system-device fs))))) file-systems))

(define (persisted-directory fs)
  (and (memq 'bind-mount
             (file-system-flags fs))
       (string-prefix? (string-append %persist "/")
                       (file-system-device fs))
       (file-system-mount-point fs)))

(define (user-name account)
  (and (not (user-account-system? account))
       (not (string=? (user-account-name account) "root"))
       (user-account-name account)))

(define (system-facts os)
  (layout-facts (operating-system-file-systems os)
                (operating-system-mapped-devices os))
  (for-each (cut fact
                 'persisted <>)
            (filter-map persisted-directory
                        (operating-system-file-systems os)))
  (for-each (cut fact
                 'user <>)
            (filter-map user-name
                        (operating-system-users os))))

(match (command-line)
  ((_ "layout" host)
   (layout-facts (host-variable host
                                'hardware
                                '%file-systems)
                 (host-variable host
                                'hardware
                                '%mapped-devices)))
  ((_ "system" host)
   (system-facts (host-variable host
                                'system
                                '%system))))
