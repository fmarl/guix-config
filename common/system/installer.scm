;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2019 Alex Griffin <a@ajgrf.com>
;;; Copyright © 2019 Pierre Neidhardt <mail@ambrevar.xyz>
;;; Copyright © 2019,2024 David Wilson <david@daviwil.com>
;;; Copyright © 2022 Jonathan Brielmaier <jonathan.brielmaier@web.de>
;;; Copyright © 2024 Hilton Chain <hako@ultrarare.space>
;;; Copyright © 2025, 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common system installer)
  #:use-module (guix)
  #:use-module (guix channels)
  #:use-module (gnu packages base)
  #:use-module (gnu packages cryptsetup)
  #:use-module (gnu packages curl)
  #:use-module (gnu packages disk)
  #:use-module (gnu packages emacs)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages package-management)
  #:use-module (gnu packages version-control)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu system)
  #:use-module (gnu system install)
  #:use-module (nongnu packages linux)
  #:use-module (common host)
  #:use-module (common system base))

(define %root
  (dirname (dirname (dirname (current-filename)))))

(define %channels
  (eval (call-with-input-file (string-append %root "/channels-lock.scm")
          read)
        (current-module)))

(define guix-config
  (local-file %root
              "guix-config"
              #:recursive? #t
              #:select? (lambda (file stat)
                          (not (string=? (basename file) ".git")))))

(define %machine
  (or (getenv "INSTALLER_MACHINE")
      (error "INSTALLER_MACHINE is not set")))

(define %host-system
  (and (not (string=? %machine "generic"))
       (host-config 'system %machine)))

(define %host-kernel
  (and %host-system
       (operating-system-kernel %host-system)))

(define %installer-kernel-configs
  '("CONFIG_ISO9660_FS=m" "CONFIG_ZISOFS=y"
    "CONFIG_OVERLAY_FS=m"
    "CONFIG_SCSI=m"
    "CONFIG_BLK_DEV_SD=m"
    "CONFIG_USB_STORAGE=m"
    "CONFIG_USB_UAS=m"))

(define installer-kernel
  (if (and %host-system
           (not (stock-kernel? %host-system)))
      (customize-linux #:linux %host-kernel
                       #:configs %installer-kernel-configs) linux))

(define machine-files
  `(("guix-config-machine" ,(plain-file "guix-config-machine"
                                        (string-append %machine "\n")))
    ,@(if %host-kernel
          `(("guix-config-kernel" ,%host-kernel))
          '())))

(define installation-os-nonfree
  (operating-system
    (inherit installation-os)
    (kernel installer-kernel)
    (initrd-modules (list "nvme"
                          "usbhid"
                          "hid-generic"
                          "usb-storage"
                          "uas"
                          "sd_mod"))
    (firmware (list linux-firmware))

    (kernel-arguments '("net.ifnames=0"))

    (services
     (cons* (simple-service 'guix-config etc-service-type
                            `(("guix-config" ,guix-config)
                              ,@machine-files))
            (modify-services (operating-system-user-services installation-os)
              (guix-service-type config =>
                                 (guix-configuration (inherit config)
                                                     (guix (guix-for-channels
                                                            %channels))
                                                     (channels %channels)))
              (special-files-service-type files =>
                                          (cons `("/usr/bin/env" ,(file-append
                                                                   coreutils
                                                                   "/bin/env"))
                                                files)))))

    (packages (append (list git
                            curl
                            emacs-no-x-toolkit
                            cryptsetup
                            parted
                            btrfs-progs
                            dosfstools)
                      (operating-system-packages installation-os)))))

installation-os-nonfree
