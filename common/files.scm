;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common files)
  #:use-module (guix gexp)
  #:use-module (guix utils)
  #:export (%config-root
            config-file))

(define %config-root
  (dirname (current-source-directory)))

(define* (config-file file #:optional (name (basename file)))
  (local-file (string-append %config-root "/" file) name))
