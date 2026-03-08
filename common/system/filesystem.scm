(define-module (common system filesystem)
  #:use-module (gnu system file-systems)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:export (btrfs-file-systems
            %hardened-base-file-systems))

;; "debugfs=off" in %hardened-kernel-arguments unregisters debugfs, so
;; mounting /sys/kernel/debug fails; that takes down file-systems, and with
;; it user-processes and every service needing it, and the boot hangs.
(define %hardened-base-file-systems
  (remove (lambda (fs)
            (string=? (file-system-type fs) "debugfs"))
          %base-file-systems))

(define* (btrfs-file-systems device options subvolumes
                             #:key (dependencies '()))
  "Return one btrfs file system per (MOUNT-POINT SUBVOLUME) in SUBVOLUMES,
all on DEVICE and mounted with OPTIONS."
  (map (match-lambda
         ((mount-point subvolume)
          (file-system
            (device device)
            (mount-point mount-point)
            (type "btrfs")
            (options (string-append "subvol=" subvolume "," options))
            (dependencies dependencies))))
       subvolumes))
