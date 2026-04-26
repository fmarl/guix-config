(define-module (hosts thinkpad hardware)
  #:use-module (gnu)
  #:use-module (common system filesystem)
  #:export (%mapped-devices
            %file-systems))

(define %mapped-devices
  (list (mapped-device
          (source "/dev/nvme0n1p3")
          (target "guix-root")
          (type luks-device-mapping)
          (arguments (list #:allow-discards? #t)))))

(define %file-systems
  (append (btrfs-file-systems "/dev/mapper/guix-root"
                              "compress=zstd:3,discard=async"
                              '(("/"           "@")
                                ("/home"       "@home")
                                ("/var/tmp"    "@tmp")
                                ("/var/cache"  "@cache")
                                ("/var/log"    "@log")
                                ("/gnu/store"  "@store")
                                ("/.snapshots" "@snapshots"))
                              #:dependencies %mapped-devices)
          (list (file-system
                  (mount-point "/boot/efi")
                  (device (uuid "8368-1369" 'fat32))
                  (type "vfat")
                  (options "umask=0077")))))
