(define-module (hosts thinkpad system)
  #:use-module (gnu)
  #:use-module (gnu services desktop)
  #:use-module (nongnu packages linux)
  #:use-module (common system base)
  #:use-module (common system desktop)
  #:use-module (common system filesystem)
  #:use-module (common system kernel)
  #:use-module (common system networking)
  #:export (%system))

(define %system
  (operating-system
    (inherit %base-os)
    (host-name "thinkpad")
    (kernel (linux-with-defconfig (local-file "defconfig")))
    (initrd-modules (list "nvme" "usbhid" "hid-generic" "dm-crypt"))
    (firmware (cons* ibt-hw-firmware iwlwifi-firmware %base-firmware))

    (services
     (append (niri-session)
             (network-services)
             (list (service bluetooth-service-type))
             (operating-system-user-services %base-os)))

    (swap-devices (list (swap-space
                          (target (uuid "30698a64-604a-4cb9-9e24-d51a64c22c4e")))))

    (mapped-devices (list (mapped-device
                            (source "/dev/nvme0n1p3")
                            (target "guix-root")
                            (type (luks-device-mapping-with-options
                                   #:allow-discards? #t)))))

    (file-systems
     (append (btrfs-file-systems "/dev/mapper/guix-root"
                                 "compress=zstd:3,discard=async"
                                 '(("/"           "@")
                                   ("/home"       "@home")
                                   ("/var/tmp"    "@tmp")
                                   ("/var/cache"  "@cache")
                                   ("/var/log"    "@log")
                                   ("/gnu/store"  "@store")
                                   ("/.snapshots" "@snapshots"))
                                 #:dependencies mapped-devices)
             (list (file-system
                     (mount-point "/boot/efi")
                     (device (uuid "8368-1369" 'fat32))
                     (type "vfat")))
             %hardened-base-file-systems))))

%system
