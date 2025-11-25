(use-modules (gnu)
	     (nongnu packages linux)
	     (nongnu system linux-initrd)
	     (gnu packages)
	     (my networking)
	     (my desktop)
	     (my base)
	     (my filesystem))
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
   (make-desktop)
   
   (make-network)

   %my-base-services))
 
 (bootloader (bootloader-configuration
              (bootloader grub-efi-bootloader)
              (targets (list "/boot/efi"))
              (keyboard-layout keyboard-layout)))
 
 (swap-devices (list (swap-space
                      (target (uuid
                               "98f80efd-ddbe-4556-b70a-e317fe8c539d")))))

 (mapped-devices
  (list
   (mapped-device
    (source "/dev/nvme0n1p3")
    (target "cryptroot")
    (type luks-device-mapping))))
 
 (file-systems (append
		(btrfs-filesystems
		 "/dev/mapper/cryptroot"
		 '(("/"           "subvol=@,compress-force=zstd,space_cache=v2,ssd,discard=async")
		   ("/home"       "subvol=@home,compress-force=zstd,space_cache=v2,ssd,discard=async")
		   ("/boot"       "subvol=@boot,compress-force=zstd,space_cache=v2,ssd,discard=async")
		   ("/var/log"    "subvol=@volatile-log,compress-force=zstd,space_cache=v2,ssd,discard=async")
		   ("/gnu/store"        "subvol=@gnu,compress-force=zstd,space_cache=v2,ssd,discard=async")
		   ("/.snapshots" "subvol=.snapshots,compress-force=zstd,space_cache=v2,ssd,discard=async"))
                 mapped-devices)
		
		(list
		 (file-system
                  (mount-point "/boot/efi")
                  (device (uuid "CE94-679E"
				'fat32))
                  (type "vfat")))
		
		%base-file-systems)))
