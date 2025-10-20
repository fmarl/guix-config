;; This is an operating system configuration generated
;; by the graphical installer.
;;
;; Once installation is complete, you can learn and modify
;; this file to tweak the system configuration, and pass it
;; to the 'guix system reconfigure' command to effect your
;; changes.


;; Indicate which modules to import to access the variables
;; used in this configuration.
(use-modules (gnu))
(use-service-modules cups desktop networking ssh xorg)

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
                  (home-directory "/home/marrero")
                  (supplementary-groups '("wheel" "netdev" "audio" "video")))
                %base-user-accounts))

  ;; Packages installed system-wide.  Users can also install packages
  ;; under their own account: use 'guix search KEYWORD' to search
  ;; for packages and 'guix install PACKAGE' to install a package.
  ;;(packages (append (list (specification->package "nss-certs"))
  ;;                  %base-packages))

  ;; Below is the list of system services.  To search for available
  ;; services, run 'guix system search KEYWORD' in a terminal.
  (services
   (append 
    (list
     (service mate-desktop-service-type)
		(set-xorg-configuration
                 (xorg-configuration (keyboard-layout keyboard-layout)))
     (service openssh-service-type))
    %desktop-services))
  
  (bootloader (bootloader-configuration
                (bootloader grub-efi-bootloader)
                (targets (list "/boot/efi"))
                (keyboard-layout keyboard-layout)))
  
  (swap-devices (list (swap-space
                        (target (uuid
                                 "6df8d888-ef43-4a42-b01e-4469d8fb2f02")))))

  ;; The list of file systems that get "mounted".  The unique
  ;; file system identifiers there ("UUIDs") can be obtained
  ;; by running 'blkid' in a terminal.
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
