;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common system base)
  #:use-module (guix gexp)
  #:use-module (gnu)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages fonts)
  #:use-module (gnu packages linux)
  #:use-module (gnu services admin)
  #:use-module (gnu services linux)
  #:use-module (gnu services shepherd)
  #:use-module (gnu services sysctl)
  #:use-module (gnu system locale)
  #:use-module (nongnu packages linux)
  #:use-module (nongnu system linux-initrd)
  #:use-module (common locale)
  #:use-module (common machines)
  #:use-module (common system desktop)
  #:use-module (common system filesystem)
  #:use-module (common system impermanence)
  #:use-module (common system maintenance)
  #:use-module (common system security)
  #:use-module (common themes)
  #:use-module (common users)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:export (base-operating-system stock-kernel?))

(define base-services
  (cons* (service login-service-type)
         (service virtual-terminal-service-type)
         (service console-font-service-type
                  (map (lambda (tty)
                         (cons tty
                               (file-append font-terminus
                                "/share/consolefonts/ter-116n.psf.gz")))
                       '("tty1" "tty2" "tty3")))
         (service shepherd-system-log-service-type)
         (service etc-bashrc-d-service-type)
         (service zram-device-service-type
                  (zram-device-configuration (size "8G")
                                             (compression-algorithm 'zstd)
                                             (priority 100)))
         (simple-service 'zram-sysctl sysctl-service-type
                         '(("vm.swappiness" . "180") ("vm.page-cluster" . "0")))
         (service guix-service-type
                  (guix-configuration (tmpdir "/var/tmp")))
         (service nscd-service-type)
         (service log-rotation-service-type
                  (log-rotation-configuration (calendar-event #~(calendar-event
                                                                 #:minutes '(0)
                                                                 #:hours '(12)))))
         (service shepherd-timer-service-type)
         (service shepherd-transient-service-type)
         (service log-cleanup-service-type
                  (log-cleanup-configuration (directory "/var/log/guix/drvs")))

         (service udev-service-type
                  (udev-configuration (rules (list lvm2 fuse alsa-utils crda))))

         (service special-files-service-type
                  `(("/bin/sh" ,(file-append bash "/bin/sh"))
                    ("/usr/bin/env" ,(file-append coreutils "/bin/env"))))

         %maintenance-services))

(define %hardened-kernel-arguments
  '("slab_nomerge" "page_alloc.shuffle=1"))

(define (console-palette-arguments theme)
  (map (match-lambda
         ((channel . select) (string-append "vt.default_" channel "="
                                            (string-join (map (compose
                                                               number->string
                                                               select)
                                                              (console-palette
                                                               theme)) ","))))
       `(("red" unquote first)
         ("grn" unquote second)
         ("blu" unquote third))))

(define* (base-operating-system machine
                                #:key kernel-config
                                initrd-modules
                                (kernel-arguments '())
                                (firmware %base-firmware)
                                (mapped-devices '())
                                (file-systems '())
                                (persisted-directories '())
                                (snapshot-directories '())
                                (guix-daemon-options '())
                                (services '()))
  (define kernel
    (if kernel-config
        (customize-linux #:linux linux
                         #:defconfig kernel-config) linux))

  (define desktop?
    (and (machine-wm machine) #t))

  (operating-system
    (host-name (symbol->string (machine-name machine)))
    (kernel kernel)
    (kernel-arguments (append %hardened-kernel-arguments kernel-arguments
                              (console-palette-arguments (machine-theme
                                                          machine))
                              %default-kernel-arguments))
    (initrd microcode-initrd)
    (initrd-modules (or initrd-modules
                        (base-initrd-modules kernel)))
    (firmware firmware)
    (locale "en_US.utf8")
    (locale-definitions (cons (locale-definition (name (string-append
                                                        %regional-locale
                                                        ".utf8"))
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
    (mapped-devices mapped-devices)
    (file-systems (append file-systems
                          (persisted-file-systems file-systems
                                                  persisted-directories)
                          %hardened-base-file-systems))
    (services
     (append (if desktop?
                 (desktop-session machine)
                 '())
             services
             (if desktop? %desktop-base-services
                 '())
             %security-services
             (btrfs-maintenance-services (snapshot-subvolumes file-systems
                                                              snapshot-directories))
             (impermanence-services file-systems persisted-directories
                                    (list (user-name %user)))
             (modify-services base-services
               (guix-service-type config =>
                                  (guix-configuration (inherit config)
                                                      (extra-options
                                                       guix-daemon-options))))))))

(define (stock-kernel? os)
  (eq? (operating-system-kernel os) linux))
