;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common home gnupg)
  #:use-module (guix gexp)
  #:use-module (gnu packages gnupg)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:use-module (gnu home services gnupg)
  #:use-module (common home bemenu)
  #:use-module (common home helpers)
  #:export (%gpg-services))

;; https://github.com/drduh/config/blob/master/gpg.conf
(define gpg-conf
  (key-value-file
   "gpg.conf"
   '(("personal-cipher-preferences" . "AES256 AES192 AES")
     ("personal-digest-preferences" . "SHA512 SHA384 SHA256")
     ("personal-compress-preferences" . "Uncompressed ZLIB BZIP2 ZIP")
     ("no-comments" . #t)
     ("keyid-format" . "0xlong")
     ("list-options" . "show-uid-validity")
     ("verify-options" . "show-uid-validity")
     ("with-fingerprint" . #t)
     ("no-symkey-cache" . #t))))

;; https://support.yubico.com/hc/en-us/articles/4819584884124-Resolving-GPG-s-CCID-conflicts
(define scdaemon-conf
  (key-value-file "scdaemon.conf"
                  '(("disable-ccid" . #t))))

(define %gpg-services
  (list (home-packages gnupg)
        (service home-gpg-agent-service-type
                 (home-gpg-agent-configuration
                  (pinentry-program pinentry-bemenu*)
                  (default-cache-ttl 60)
                  (max-cache-ttl 120)))
        (simple-service 'gpg-config
                        home-files-service-type
                        `((".gnupg/gpg.conf" ,gpg-conf)
                          (".gnupg/scdaemon.conf" ,scdaemon-conf)))))
