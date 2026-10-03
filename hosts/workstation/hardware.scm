(define-module (hosts workstation hardware)
  #:use-module (gnu)
  #:use-module (common system filesystem)
  #:export (%mapped-devices
            %file-systems))

(define %mapped-devices '())

(define %file-systems
  (append (btrfs-file-systems (file-system-label "ROOT")
                              "compress-force=zstd,space_cache=v2,ssd,discard=async"
                              '(("/"           "@")
                                ("/home"       "@home")
                                ("/boot"       "@boot")
                                ("/var/log"    "@log")
                                ("/gnu"        "@gnu")
                                ("/.snapshots" ".snapshots")))
          (list (file-system
                  (mount-point "/boot/efi")
                  (device (uuid "A196-47A5" 'fat32))
                  (type "vfat")))))
