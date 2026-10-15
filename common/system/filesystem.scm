;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common system filesystem)
  #:use-module (gnu system file-systems)
  #:use-module (gnu system uuid)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-26)
  #:use-module ((guix-impermanence file-systems)
                #:select (%persist impermanent-file-systems?
                          tmpfs-root-file-system))
  #:re-export (%persist impermanent-file-systems?)
  #:export (%btrfs-options
                     %btrfs-top-level
                     %snapshot-subvolume
                     btrfs-file-systems
                     impermanent-file-systems
                     btrfs-subvolumes
                     snapshot-subvolumes
                     %hardened-base-file-systems))

(define %btrfs-options
  "compress=zstd:1,discard=async")

(define %btrfs-top-level
  "/.btrfs")

(define %snapshot-subvolume
  "@snapshots")

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
        (flags (cons 'no-exec
                     (file-system-flags fs)))) fs))

(define %hardened-base-file-systems
  (cons %tmp-file-system
        (map harden-file-system
             (remove (lambda (fs)
                       (string=? (file-system-type fs) "debugfs"))
                     %base-file-systems))))

(define %default-subvolumes
  '(("/" "@")
    ("/gnu" "@gnu" no-suid no-dev)
    ("/home" "@home" no-suid no-dev)
    ("/var/log" "@log" no-suid no-dev no-exec)
    ("/var/tmp" "@tmp" no-suid no-dev)))

(define %impermanent-subvolumes
  (append (alist-delete "/" %default-subvolumes)
          `((,%persist "@persist" no-suid no-dev)
            ("/boot" "@boot" no-suid no-dev no-exec))))

(define (merge-subvolumes defaults subvolumes)
  (append (remove (lambda (default)
                    (assoc (first default) subvolumes)) defaults) subvolumes))

(define (subvolume-file-system device options dependencies subvolume)
  (match subvolume
    ((mount-point name . flags) (file-system
                                  (device device)
                                  (mount-point mount-point)
                                  (type "btrfs")
                                  (options (string-append "subvol=" name ","
                                                          options))
                                  (flags (cons 'no-atime flags))
                                  (needed-for-boot? (string=? mount-point
                                                              %persist))
                                  (dependencies dependencies)))))

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
    (device (uuid esp
                  'fat32))
    (type "vfat")
    (flags '(no-suid no-dev no-exec))
    (options "umask=0077")
    (dependencies (filter (lambda (fs)
                            (string=? (file-system-mount-point fs) "/boot"))
                          file-systems))))

(define (layout-file-systems device options subvolumes esp dependencies)
  (let ((file-systems (cons (top-level-file-system device options dependencies)
                            (map (cut subvolume-file-system device options
                                      dependencies <>) subvolumes))))
    (append file-systems
            (list (efi-file-system esp file-systems)))))

(define* (btrfs-file-systems device
                             #:key esp
                             (options %btrfs-options)
                             (subvolumes '())
                             (dependencies '()))
  (layout-file-systems device options
                       (merge-subvolumes %default-subvolumes subvolumes) esp
                       dependencies))

(define* (impermanent-file-systems device
                                   #:key esp
                                   (options %btrfs-options)
                                   (subvolumes '())
                                   (dependencies '()))
  (cons (tmpfs-root-file-system)
        (layout-file-systems device options
                             (merge-subvolumes %impermanent-subvolumes
                                               subvolumes) esp dependencies)))

(define (file-system-subvolume fs)
  (and (string=? (file-system-type fs) "btrfs")
       (assoc-ref (file-system-options->alist (file-system-options fs))
                  "subvol")))

(define (btrfs-subvolumes file-systems)
  (define mounted
    (filter-map (lambda (fs)
                  (and=> (file-system-subvolume fs)
                         (cut cons <>
                              (file-system-mount-point fs)))) file-systems))

  (append (sort mounted
                (lambda (a b)
                  (string<? (cdr a)
                            (cdr b))))
          (list (cons %snapshot-subvolume #f))))

(define* (snapshot-subvolumes file-systems
                              #:optional (mount-points '()))
  (filter-map (lambda (fs)
                (and (member (file-system-mount-point fs)
                             (cons* "/home" %persist mount-points))
                     (file-system-subvolume fs))) file-systems))
