(use-modules (gnu)
	     (nongnu packages linux)
	     (nongnu system linux-initrd)
	     (gnu packages)
	     (my networking)
	     (my desktop))
(use-service-modules desktop ssh xorg)

(operating-system
 (kernel linux)
 (initrd microcode-initrd)
 (firmware (cons*
	    iwlwifi-firmware
	    %base-firmware))
 (locale "en_US.utf8")
 (timezone "Europe/Berlin")
 (keyboard-layout (keyboard-layout "us" "altgr-intl"))
 (host-name "lepton")

 ;; The list of user accounts ('root' is implicit).
 (users (cons* (user-account
                (name "marrero")
                (comment "Florian Marrero Liestmann")
                (group "users")
		(shell (file-append (specification->package "zsh") "/bin/zsh"))
                (home-directory "/home/marrero")
                (supplementary-groups '("wheel" "netdev" "audio" "video" "seat" "plugdev")))
               %base-user-accounts))

 (services
  (append
   (make-desktop (list river-desktop-services))

   network-manager-service

   (list (make-firewall-service))
   
   (modify-services %base-services
		    (delete agetty-service-type)
		    (delete login-service-type)
		    (delete console-font-service-type)
		    (delete mingetty-service-type))))
 
 (bootloader (bootloader-configuration
              (bootloader grub-efi-bootloader)
              (targets (list "/boot/efi"))
              (keyboard-layout keyboard-layout)))
 
 ;;(swap-devices (list (swap-space
 ;;                     (target (uuid
 ;;                              "")))))

 (mapped-devices
  (list
   (mapped-device
    (source "/dev/nvme0n1p3")
    (target "cryptroot")
    (type luks-device-mapping))))
 
 (file-systems (cons*
		(file-system
                 (mount-point "/")
                 (device "/dev/mapper/cryptroot")
                 (type "btrfs")
		 (options "subvol=@,compress-force=zstd,space_cache=v2,ssd,discard=async")
		 (dependencies mapped-devices))
		(file-system
                 (mount-point "/home")
		 (device "/dev/mapper/cryptroot")
                 (dependencies mapped-devices)
                 (type "btrfs")
		 (options "subvol=@home,compress-force=zstd,space_cache=v2,ssd,discard=async"))
		(file-system
                 (mount-point "/boot")
		 (device "/dev/mapper/cryptroot")
                 (dependencies mapped-devices)
                 (type "btrfs")
		 (options "subvol=@boot,compress-force=zstd,space_cache=v2,ssd,discard=async"))
		(file-system
                 (mount-point "/var/log")
		 (device "/dev/mapper/cryptroot")
                 (dependencies mapped-devices)
                 (type "btrfs")
		 (options "subvol=@volatile-log,compress-force=zstd:3,space_cache=v2,ssd,discard=async"))
		(file-system
                 (mount-point "/gnu/")
		 (device "/dev/mapper/cryptroot")
		 (dependencies mapped-devices)
                 (type "btrfs")
		 (options "subvol=@gnu,compress-force=zstd:3,space_cache=v2,ssd,discard=async"))
		(file-system
                 (mount-point "/.snapshots")
		 (device "/dev/mapper/cryptroot")
		 (dependencies mapped-devices)
                 (type "btrfs")
		 (options "subvol=.snapshots,compress-force=zstd,space_cache=v2,ssd,discard=async"))
		(file-system
                 (mount-point "/boot/efi")
                 (device (uuid "CE94-679E"
                               'fat32))
                 (type "vfat")) %base-file-systems)))
