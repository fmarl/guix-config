(define-module (common system filesystem)
  #:use-module (gnu system file-systems)
  #:use-module (ice-9 match)
  #:export (btrfs-file-systems))

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
