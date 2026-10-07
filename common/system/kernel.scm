;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common system kernel)
  #:use-module (nongnu packages linux)
  #:use-module (gnu packages linux)
  #:export (linux-with-defconfig
            %hardened-kernel-arguments))

(define (linux-with-defconfig config)
  (customize-linux #:linux linux
                   #:defconfig config))

(define %hardened-kernel-arguments
  '("slab_nomerge"
    "page_alloc.shuffle=1"
    "debugfs=off"))
