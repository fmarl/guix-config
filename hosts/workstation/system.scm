(use-modules (gnu)
	     (nongnu packages linux)
	     (nongnu system linux-initrd)
	     (gnu packages)
	     (my networking)
	     (my desktop)
	     (my base))
(use-service-modules desktop ssh xorg)

(operating-system
 (kernel linux)
 (initrd microcode-initrd)
 (firmware (list amdgpu-firmware))
 (locale "en_US.utf8")
 (timezone "Europe/Berlin")
 (keyboard-layout (keyboard-layout "us" "altgr-intl"))
 (host-name "workstation")

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
   
   (make-network
    #:nic-config (make-static-network-service "enp5s0" "192.168.0.200/24"))
   
   (list
    (service openssh-service-type))

   %my-base-services))
  
 (bootloader (bootloader-configuration
              (bootloader grub-efi-bootloader)
              (targets (list "/boot/efi"))
              (keyboard-layout keyboard-layout)))
  
 (swap-devices (list (swap-space
                     (target (uuid "2ed570db-c148-4e3f-a3b5-d0c71b4cc5e9")))))

 (file-systems (cons*
		(file-system
                 (mount-point "/")
                 (device (file-system-label "ROOT"))
                 (type "btrfs")
		 (options "subvol=@,compress-force=zstd,space_cache=v2,ssd,discard=async"))
		(file-system
                 (mount-point "/home")
                 (device (file-system-label "ROOT"))
                 (type "btrfs")
		 (options "subvol=@home,compress-force=zstd,space_cache=v2,ssd,discard=async"))
		(file-system
                 (mount-point "/boot")
                 (device (file-system-label "ROOT"))
                 (type "btrfs")
		 (options "subvol=@boot,compress-force=zstd,space_cache=v2,ssd,discard=async"))
		(file-system
                 (mount-point "/var/log")
                 (device (file-system-label "ROOT"))
                 (type "btrfs")
		 (options "subvol=@log,compress-force=zstd:3,space_cache=v2,ssd,discard=async"))
		(file-system
                 (mount-point "/gnu")
                 (device (file-system-label "ROOT"))
                 (type "btrfs")
		 (options "subvol=@gnu,compress-force=zstd:3,space_cache=v2,ssd,discard=async"))
		(file-system
                 (mount-point "/.snapshots")
                 (device (file-system-label "ROOT"))
                 (type "btrfs")
		 (options "subvol=.snapshots,compress-force=zstd,space_cache=v2,ssd,discard=async"))
		(file-system
                 (mount-point "/boot/efi")
                 (device (uuid "A196-47A5"
                               'fat32))
                 (type "vfat")) %base-file-systems)))
