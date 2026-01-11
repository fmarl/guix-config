(use-modules (gnu)
	     (nongnu system linux-initrd)
	     (nongnu packages linux)
	     (gnu packages)
	     (my networking)
	     (my desktop)
	     (my base)
	     (my filesystem)
	     (my linux))
(use-service-modules desktop ssh xorg)

(operating-system
 (kernel linux-hardened)
 (initrd microcode-initrd)
 (firmware (cons*
	    iwlwifi-firmware
	    %base-firmware))
 (locale "en_US.utf8")
 (timezone "Europe/Berlin")
 (keyboard-layout (keyboard-layout "us" "altgr-intl"))
 (host-name "thinkpad")

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
                               "30698a64-604a-4cb9-9e24-d51a64c22c4e")))))

 (mapped-devices
  (list
   (mapped-device
    (source "/dev/nvme0n1p3")
    (target "guix-root")
    (type luks-device-mapping))))
 
 (file-systems (append
		(btrfs-filesystems
		 "/dev/mapper/guix-root"
		 '(("/"           "subvol=@,compress=zstd:3,discard=async")
		   ("/home"       "subvol=@home,compress=zstd:3,discard=async")
		   ("/var/tmp"    "subvol=@tmp,compress=zstd:3,discard=async")
		   ("/var/cache"  "subvol=@cache,compress=zstd:3,discard=async")
		   ("/var/log"    "subvol=@log,compress=zstd:3,discard=async")
		   ("/gnu/store"  "subvol=@store,compress=zstd:3,discard=async")
		   ("/.snapshots" "subvol=@snapshots,compress=zstd:3,discard=async"))
                 mapped-devices)
		
		(list
		 (file-system
                  (mount-point "/boot/efi")
                  (device (uuid "8368-1369"
				'fat32))
                  (type "vfat")))
		
		%base-file-systems)))
