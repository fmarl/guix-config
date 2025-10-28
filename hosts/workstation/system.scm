(use-modules (gnu)
	     (gnu packages)
	     (my networking)
	     (my desktop))
(use-service-modules desktop ssh xorg)

(operating-system
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
   ;; We remove these because we use greetd.
   (modify-services %base-services
		    (delete login-service-type)
		    (delete mingetty-service-type))
   
   (make-desktop (list
		  mate-desktop-services
		  river-desktop-services))

   (list
    (service openssh-service-type)
    (make-static-network "enp5s0" "192.168.0.200/24"))

   %base-services))
  
 (bootloader (bootloader-configuration
              (bootloader grub-efi-bootloader)
              (targets (list "/boot/efi"))
              (keyboard-layout keyboard-layout)))
  
 (swap-devices (list (swap-space
                      (target (uuid
                               "6df8d888-ef43-4a42-b01e-4469d8fb2f02")))))

 (file-systems (cons* (file-system
                       (mount-point "/")
                       (device (uuid
                                "d2f8ab96-ec15-4114-ab80-c6c7786cbe87"
                                'xfs))
                       (type "xfs"))
                      (file-system
                       (mount-point "/boot/efi")
                       (device (uuid "D9B9-0B32"
                                     'fat32))
                       (type "vfat")) %base-file-systems)))
