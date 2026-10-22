;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common home mail)
  #:use-module (gnu home services)
  #:use-module (sagittarius locked mail)
  #:use-module (common files)
  #:use-module (common home helpers)
  #:export (%mail-services))

(define %mail-services
  (list (home-packages mbsync-locked msmtp-locked mu-locked)
        (simple-service 'mail-config home-files-service-type
                        `((".mbsyncrc"
                           ,(config-file "dotfiles/.mbsyncrc" "mbsyncrc"))
                          (".msmtprc"
                           ,(config-file "dotfiles/.msmtprc" "msmtprc"))))))
