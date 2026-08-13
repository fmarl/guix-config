;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (hosts thinkpad hardware)
  #:use-module (gnu)
  #:use-module (common system filesystem)
  #:export (%mapped-devices
            %file-systems))

(define %mapped-devices
  (list (mapped-device
          (source (uuid "21bd6649-83f1-45cb-b47f-3cd64ca6dc7a"))
          (target "guix-root")
          (type luks-device-mapping)
          (arguments (list #:allow-discards? #t)))))

(define %file-systems
  (append (btrfs-file-systems "/dev/mapper/guix-root"
                              "compress=zstd:3,discard=async"
                              '(("/"           "@")
                                ("/home"       "@home")
                                ("/gnu"        "@gnu")
                                ("/var/log"    "@log")
                                ("/.snapshots" "@snapshots"))
                              #:flags '(no-atime)
                              #:dependencies %mapped-devices)
          (list (file-system
                  (mount-point "/boot/efi")
                  (device (uuid "7A59-010E" 'fat32))
                  (type "vfat")
                  (options "umask=0077")))))
