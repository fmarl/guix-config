;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common system filesystem)
  #:use-module (gnu system file-systems)
  #:use-module (gnu system uuid)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:export (btrfs-file-systems efi-file-system %hardened-base-file-systems))

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

(define* (btrfs-file-systems device options subvolumes
                             #:key (dependencies '()))
  (define (btrfs-file-system mount-point subvolume flags)
    (file-system
      (device device)
      (mount-point mount-point)
      (type "btrfs")
      (options (string-append "subvol=" subvolume "," options))
      (flags (cons 'no-atime flags))
      (dependencies dependencies)))

  (map (match-lambda
         ((mount-point subvolume)
          (btrfs-file-system mount-point subvolume
                             '()))
         ((mount-point subvolume flags)
          (btrfs-file-system mount-point subvolume flags))) subvolumes))

(define (efi-file-system uuid-string)
  (file-system
    (mount-point "/boot/efi")
    (device (uuid uuid-string
                  'fat32))
    (type "vfat")
    (flags '(no-suid no-dev no-exec))
    (options "umask=0077")))
