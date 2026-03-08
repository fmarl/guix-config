(define-module (hosts workstation system)
  #:use-module (gnu)
  #:use-module (gnu services ssh)
  #:use-module (nongnu packages linux)
  #:use-module (common users)
  #:use-module (common system base)
  #:use-module (common system desktop)
  #:use-module (common system filesystem)
  #:use-module (common system kernel)
  #:use-module (common system networking)
  #:export (%system))

(define %system
  (operating-system
    (inherit %base-os)
    (host-name "workstation")
    (kernel (linux-with-defconfig (local-file "defconfig")))
    (initrd-modules (list "nvme" "usbhid" "hid-generic"))
    (firmware (list amdgpu-firmware))

    (users (append (make-user-accounts #:extra-groups '("kvm"))
                   %base-user-accounts))

    (services
     (append (niri-session)
             (network-services #:static 'workstation #:allow-ssh? #t)
             (list (service openssh-service-type
                     (openssh-configuration
                       (password-authentication? #f)
                       (permit-root-login #f)
                       (challenge-response-authentication? #f)
                       (x11-forwarding? #f)
                       ;; StreamLocalBindUnlink is needed for gpg-agent forwarding
                       (extra-content (string-append
                                       "AllowUsers " (user-name %primary-user) "\n"
                                       "StreamLocalBindUnlink yes\n")))))
             (operating-system-user-services %base-os)))

    (swap-devices (list (swap-space
                          (target (uuid "2ed570db-c148-4e3f-a3b5-d0c71b4cc5e9")))))

    (file-systems
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
                     (type "vfat")))
             %hardened-base-file-systems))))

%system
