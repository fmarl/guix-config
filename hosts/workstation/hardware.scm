;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (hosts workstation hardware)
  #:use-module (gnu)
  #:use-module (common system filesystem)
  #:export (%mapped-devices %file-systems))

(define %mapped-devices
  '())

(define %file-systems
  (btrfs-file-systems (file-system-label "ROOT")
                      "compress=zstd:3,discard=async"
                      #:esp "A196-47A5"
                      #:subvolumes '(("/boot" "@boot"
                                      (no-suid no-dev no-exec)))))
