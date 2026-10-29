;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common system base)
  #:use-module (guix gexp)
  #:use-module (gnu)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages fonts)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages networking)
  #:use-module (gnu packages nss)
  #:use-module (gnu packages text-editors)
  #:use-module (gnu packages wget)
  #:use-module (gnu services admin)
  #:use-module (gnu services linux)
  #:use-module (gnu services shepherd)
  #:use-module (gnu services sysctl)
  #:use-module (gnu system locale)
  #:use-module (nongnu packages linux)
  #:use-module (nongnu system linux-initrd)
  #:use-module ((guix-impermanence services)
                #:select (impermanent-operating-system))
  #:use-module (common locale)
  #:use-module (common machines)
  #:use-module (common system desktop)
  #:use-module (common system filesystem)
  #:use-module (common system laptop)
  #:use-module (common system maintenance)
  #:use-module (common system networking)
  #:use-module (common system security)
  #:use-module (common system syncthing)
  #:use-module (common themes)
  #:use-module (common users)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:export (base-operating-system
            stock-kernel?))

(define base-services
  (cons* (service login-service-type)
         (service virtual-terminal-service-type)
         (service console-font-service-type
                  (map (lambda (tty)
                         (cons tty
                               (file-append
                                font-terminus
                                "/share/consolefonts/ter-116n.psf.gz")))
                       '("tty1" "tty2" "tty3")))
         (service shepherd-system-log-service-type)
         (service etc-bashrc-d-service-type)
         (service zram-device-service-type
                  (zram-device-configuration
                   (size "8G")
                   (compression-algorithm 'zstd)
                   (priority 100)))
         (simple-service 'zram-sysctl sysctl-service-type
                         '(("vm.swappiness" . "180")
                           ("vm.page-cluster" . "0")))
         (service guix-service-type
                  (guix-configuration
                   (tmpdir "/var/tmp")))
         (service nscd-service-type)
         (service log-rotation-service-type
                  (log-rotation-configuration
                   (calendar-event #~(calendar-event #:minutes '(0)
                                                     #:hours '(12)))))
         (service shepherd-timer-service-type)
         (service shepherd-transient-service-type)
         (service log-cleanup-service-type
                  (log-cleanup-configuration
                   (directory "/var/log/guix/drvs")))

         (service udev-service-type)

         (service special-files-service-type
                  `(("/bin/sh" ,(file-append bash "/bin/sh"))
                    ("/usr/bin/env" ,(file-append coreutils "/bin/env"))))

         %maintenance-services))

(define %console-services
  (map (lambda (tty)
         (service mingetty-service-type
                  (mingetty-configuration (tty tty))))
       '("tty1" "tty2" "tty3")))

(define %system-packages
  (append (lset-difference eq? %base-packages-interactive (list nano nvi))
          %base-packages-linux
          (list iproute iputils wget nss-certs)
          %base-packages-utils))

(define %hardened-kernel-arguments
  '("slab_nomerge"
    "page_alloc.shuffle=1"
    "efi=disable_early_pci_dma"
    "iommu.strict=1"))

(define (console-palette-arguments theme)
  (map (match-lambda
         ((channel . select)
          (string-append "vt.default_" channel "="
                         (string-join (map (compose number->string select)
                                           (console-palette theme))
                                      ","))))
       `(("red" . ,first)
         ("grn" . ,second)
         ("blu" . ,third))))

(define* (base-operating-system machine
                                #:key
                                kernel-config
                                initrd-modules
                                (kernel-arguments '())
                                (firmware %base-firmware)
                                (mapped-devices '())
                                (file-systems '())
                                (snapshot-directories '())
                                (guix-daemon-options '())
                                (services '()))
  (define kernel
    (if kernel-config
        (customize-linux #:linux linux #:defconfig kernel-config)
        linux))

  (define desktop?
    (and (machine-wm machine) #t))

  (impermanent-operating-system
   (operating-system
     (host-name (symbol->string (machine-name machine)))
     (kernel kernel)
     (kernel-arguments
      (append %hardened-kernel-arguments
              kernel-arguments
              (console-palette-arguments (machine-theme machine))
              %default-kernel-arguments))
     (initrd microcode-initrd)
     (initrd-modules (or initrd-modules
                         (base-initrd-modules kernel)))
     (firmware firmware)
     (locale "en_US.utf8")
     (locale-definitions
      (cons (locale-definition
              (name (string-append %regional-locale ".utf8"))
              (source %regional-locale)
              (charset "UTF-8"))
            %default-locale-definitions))
     (timezone "Europe/Berlin")
     (keyboard-layout %keyboard-layout)
     (bootloader (bootloader-configuration
                   (bootloader grub-efi-bootloader)
                   (targets (list "/boot/efi"))
                   (keyboard-layout %keyboard-layout)))
     (users (cons* (user-account
                     (inherit %root-account)
                     (password "!"))
                   (primary-user-account #:desktop? desktop?)
                   %base-user-accounts))
     (sudoers-file %sudoers)
     (privileged-programs %privileged-programs)
     (mapped-devices mapped-devices)
     (file-systems (append file-systems %hardened-base-file-systems))
     (packages %system-packages)
     (services
      (append (if desktop?
                  (desktop-session machine)
                  '())
              (network-services machine)
              (if (null? (machine-ssh-clients machine))
                  '()
                  ssh-server-services)
              (if desktop?
                  '()
                  %console-services)
              (if (machine-mobile? machine)
                  %laptop-services
                  '())
              (if (machine-syncthing-hub machine)
                  %syncthing-client-services
                  '())
              services
              (if desktop?
                  %desktop-base-services
                  '())
              %hardening-services
              (if (null? mapped-devices)
                  '()
                  (list (udev-rules-service 'lvm2 lvm2)))
              (btrfs-maintenance-services
               (snapshot-subvolumes file-systems snapshot-directories))
              (modify-services base-services
                (guix-service-type
                 config => (guix-configuration
                            (inherit config)
                            (extra-options guix-daemon-options)))))))
   (list (user-name %user))))

(define (stock-kernel? os)
  (eq? (operating-system-kernel os) linux))
