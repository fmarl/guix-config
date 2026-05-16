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
     ("personal-compress-preferences" . "ZLIB BZIP2 ZIP Uncompressed")
     ("default-preference-list" . "SHA512 SHA384 SHA256 AES256 AES192 AES ZLIB BZIP2 ZIP Uncompressed")
     ("cert-digest-algo" . "SHA512")
     ("s2k-digest-algo" . "SHA512")
     ("s2k-cipher-algo" . "AES256")
     ("charset" . "utf-8")
     ("fixed-list-mode" . #t)
     ("no-comments" . #t)
     ("no-emit-version" . #t)
     ("keyid-format" . "0xlong")
     ("list-options" . "show-uid-validity")
     ("verify-options" . "show-uid-validity")
     ("with-fingerprint" . #t)
     ("require-cross-certification" . #t)
     ("no-symkey-cache" . #t)
     ("use-agent" . #t)
     ("throw-keyids" . #t))))

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
                  (max-cache-ttl 120)
                  (extra-content "allow-emacs-pinentry\n")))
        (simple-service 'gpg-config
                        home-files-service-type
                        `((".gnupg/gpg.conf" ,gpg-conf)
                          (".gnupg/scdaemon.conf" ,scdaemon-conf)))))
