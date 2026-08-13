;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common home mail)
  #:use-module (guix gexp)
  #:use-module (sagittarius locked mail)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:use-module (common home helpers)
  #:export (%mail-services))

(define %mail-services
  (list (home-packages mbsync-locked msmtp-locked mu-locked)
	(simple-service 'mail-config
			home-files-service-type
			`((".mbsyncrc"
			   ,(local-file "../../dotfiles/.mbsyncrc" "mbsyncrc"))
			  (".msmtprc"
			   ,(local-file "../../dotfiles/.msmtprc" "msmtprc"))))))
