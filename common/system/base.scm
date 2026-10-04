(define-module (common system base)
  #:use-module (guix gexp)
  #:use-module (gnu)
  #:use-module (gnu system locale)
  #:use-module (gnu services admin)
  #:use-module (gnu services linux)
  #:use-module (gnu services shepherd)
  #:use-module (gnu services sysctl)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages linux)
  #:use-module (nongnu system linux-initrd)
  #:use-module (common users)
  #:use-module (common system desktop)
  #:use-module (common system filesystem)
  #:use-module (common system kernel)
  #:use-module (common system maintenance)
  #:use-module (common system security)
  #:export (%base-os))

(define base-services
  (cons* (service login-service-type)

         (service virtual-terminal-service-type)
         (service console-font-service-type
                  (map (lambda (tty)
                         (cons tty %default-console-font))
                       '("tty1" "tty2" "tty3")))

         (service shepherd-system-log-service-type)

         ;; Extra Bash configuration including Bash completion and aliases.
         (service etc-bashrc-d-service-type)
         (service urandom-seed-service-type)
         (service zram-device-service-type
                  (zram-device-configuration
                    (size "8G")
                    (compression-algorithm 'zstd)
                    (priority 100)))
         ;; Swapping to zram is cheap
         (simple-service 'zram-sysctl sysctl-service-type
                         '(("vm.swappiness" . "180")
                           ("vm.page-cluster" . "0")))

         ;; The /tmp tmpfs is too small for builds
         (service guix-service-type
                  (guix-configuration (tmpdir "/var/tmp")))
         (service nscd-service-type)

         (service log-rotation-service-type)

         ;; Convenient services brought by the Shepherd.
         (service shepherd-timer-service-type)
         (service shepherd-transient-service-type)

         ;; Periodically delete old build logs.
         (service log-cleanup-service-type
                  (log-cleanup-configuration (directory "/var/log/guix/drvs")))

         ;; The LVM2 rules are needed as soon as LVM2 or the device-mapper is
         ;; used, so enable them by default.  The FUSE and ALSA rules are
         ;; less critical, but handy.
         (service udev-service-type
                  (udev-configuration (rules (list lvm2 fuse alsa-utils crda))))

         (service special-files-service-type
                  `(("/bin/sh" ,(file-append bash "/bin/sh"))
                    ("/usr/bin/env" ,(file-append coreutils "/bin/env"))))

         %maintenance-services))

;; Hosts inherit from this and set at least host-name, kernel and
;; file-systems, which are placeholders here.
(define %base-os
  (operating-system
    (host-name "guix")
    (kernel-arguments (append %hardened-kernel-arguments
                              %default-kernel-arguments))
    (initrd microcode-initrd)
    (locale "en_US.utf8")
    (locale-definitions (cons (locale-definition (name "de_DE.utf8")
                                                 (source "de_DE")
                                                 (charset "UTF-8"))
                              %default-locale-definitions))
    (timezone "Europe/Berlin")
    (keyboard-layout (keyboard-layout "us" "altgr-intl"))
    (bootloader (bootloader-configuration
                  (bootloader grub-efi-bootloader)
                  (targets (list "/boot/efi"))
                  (keyboard-layout keyboard-layout)))
    (users (append %user-accounts %base-user-accounts))
    (sudoers-file %sudoers)
    (file-systems %base-file-systems)
    (services (append %desktop-services
                      %security-services
                      (btrfs-maintenance-services)
                      base-services))))
