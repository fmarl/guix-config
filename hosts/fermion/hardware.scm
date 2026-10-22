;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (hosts fermion hardware)
  #:use-module (gnu)
  #:use-module (common system filesystem)
  #:export (%mapped-devices
            %file-systems
            %backup-directory
            %sync-directory))

(define %backup-directory "/srv/backup")

(define %sync-directory "/srv/sync")

(define %mapped-devices '())

(define %file-systems
  (impermanent-file-systems
   (uuid "66adccf5-1a02-435e-93a9-044b95955e89" 'btrfs)
   #:esp "C159-4A51"
   #:subvolumes (list (btrfs-subvolume
                        (mount-point %backup-directory)
                        (name "@backup")
                        (flags '(no-suid no-dev no-exec)))
                      (btrfs-subvolume
                        (mount-point %sync-directory)
                        (name "@sync")
                        (flags '(no-suid no-dev no-exec))))))
