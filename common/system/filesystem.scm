;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common system filesystem)
  #:use-module (gnu system file-systems)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:export (btrfs-file-systems %hardened-base-file-systems))

(define %tmp-file-system
  (file-system
    (mount-point "/tmp")
    (device "tmpfs")
    (type "tmpfs")
    (flags '(no-suid no-dev))
    (options "mode=1777")
    (check? #f)))

(define %hardened-base-file-systems
  (cons %tmp-file-system
        (remove (lambda (fs)
                  (string=? (file-system-type fs) "debugfs"))
                %base-file-systems)))

(define* (btrfs-file-systems device
                             options
                             subvolumes
                             #:key (flags '())
                             (dependencies '()))
  (map (match-lambda
         ((mount-point subvolume)
          (file-system
            (device device)
            (mount-point mount-point)
            (type "btrfs")
            (options (string-append "subvol=" subvolume "," options))
            (flags flags)
            (dependencies dependencies)))) subvolumes))
