;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common system filesystem)
  #:use-module (gnu system file-systems)
  #:use-module (gnu system uuid)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-26)
  #:use-module (guix-impermanence btrfs)
  #:use-module ((guix-impermanence file-systems)
                #:select (%persist
                          impermanent-file-systems?))
  #:re-export (%persist
               impermanent-file-systems?
               btrfs-subvolume)
  #:export (%btrfs-top-level
            %snapshot-subvolume
            impermanent-file-systems
            btrfs-subvolumes
            snapshot-subvolumes
            %hardened-base-file-systems))

(define %btrfs-options "compress=zstd:1,discard=async")

(define %btrfs-top-level "/.btrfs")

(define %snapshot-subvolume "@snapshots")

(define %tmp-file-system
  (file-system
    (mount-point "/tmp")
    (device "tmpfs")
    (type "tmpfs")
    (flags '(no-suid no-dev))
    (options "mode=1777")
    (check? #f)))

(define (harden-file-system fs)
  (if (string=? (file-system-mount-point fs) "/dev/shm")
      (file-system
        (inherit fs)
        (flags (cons 'no-exec (file-system-flags fs))))
      fs))

(define %hardened-base-file-systems
  (cons %tmp-file-system
        (map harden-file-system
             (remove (lambda (fs)
                       (string=? (file-system-type fs) "debugfs"))
                     %base-file-systems))))

(define (subvolume mount-point name . flags)
  (btrfs-subvolume
    (mount-point mount-point)
    (name name)
    (flags flags)))

(define %subvolumes
  (list (subvolume "/gnu" "@gnu" 'no-suid 'no-dev)
        (subvolume "/home" "@home" 'no-suid 'no-dev)
        (subvolume "/var/log" "@log" 'no-suid 'no-dev 'no-exec)
        (subvolume "/var/tmp" "@tmp" 'no-suid 'no-dev)
        (subvolume %persist "@persist" 'no-suid 'no-dev)
        (subvolume "/boot" "@boot" 'no-suid 'no-dev 'no-exec)))

(define (top-level-file-system device options dependencies)
  (file-system
    (device device)
    (mount-point %btrfs-top-level)
    (type "btrfs")
    (options (string-append "subvolid=5," options))
    (flags '(no-atime no-suid no-dev no-exec))
    (dependencies dependencies)))

(define (efi-file-system esp file-systems)
  (unless (string? esp)
    (error "missing #:esp, the UUID of the EFI system partition"))
  (file-system
    (mount-point "/boot/efi")
    (device (uuid esp 'fat32))
    (type "vfat")
    (flags '(no-suid no-dev no-exec))
    (options "umask=0077")
    (dependencies (filter (lambda (fs)
                            (string=? (file-system-mount-point fs) "/boot"))
                          file-systems))))

(define* (impermanent-file-systems device
                                   #:key
                                   esp
                                   (options %btrfs-options)
                                   (subvolumes '())
                                   (dependencies '()))
  (let ((file-systems
         (append (impermanent-btrfs-file-systems
                  device
                  #:subvolumes (merge-subvolumes %subvolumes subvolumes)
                  #:options options
                  #:flags '(no-atime)
                  #:dependencies dependencies)
                 (list (top-level-file-system device options dependencies)))))
    (append file-systems
            (list (efi-file-system esp file-systems)))))

(define (btrfs-subvolumes file-systems)
  (define mounted
    (filter-map (lambda (fs)
                  (and=> (file-system-subvolume fs)
                         (cut cons <> (file-system-mount-point fs))))
                file-systems))

  (append (sort mounted
                (lambda (a b)
                  (string<? (cdr a) (cdr b))))
          (list (cons %snapshot-subvolume #f))))

(define* (snapshot-subvolumes file-systems #:optional (mount-points '()))
  (filter-map (lambda (fs)
                (and (member (file-system-mount-point fs)
                             (cons* "/home" %persist mount-points))
                     (file-system-subvolume fs)))
              file-systems))
