;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (hosts fermion system)
  #:use-module (gnu)
  #:use-module (common machines)
  #:use-module (common syncthing)
  #:use-module (common system backup)
  #:use-module (common system base)
  #:use-module (common system syncthing)
  #:use-module (hosts fermion hardware)
  #:export (%system))

(define %machine
  (lookup-machine 'fermion))

(define %s3-region "eu-central-2")

(define %s3-repository
  (string-append "s3:https://s3-" %s3-region
                 ".ionoscloud.com/backups-default-gfw21t/restic"))

(define %s3-environment
  (list (cons "AWS_SHARED_CREDENTIALS_FILE"
              (string-append %restic-directory "/s3-credentials"))
        (cons "AWS_DEFAULT_REGION" %s3-region)))

(define* (backup-services name repository #:key (environment '()))
  (restic-services name repository
                   (list %sync-directory)
                   #:environment environment
                   #:excludes %syncthing-temporary-files))

(define %system
  (base-operating-system
   %machine
   #:kernel-config (local-file "defconfig")
   #:initrd-modules '()
   #:kernel-arguments (list "net.ifnames=0")
   #:firmware '()
   #:mapped-devices %mapped-devices
   #:file-systems %file-systems
   #:snapshot-directories (list %sync-directory)
   #:services
   (append (syncthing-server-services %sync-directory
                                      (syncthing-clients %machine))
           (backup-services 'local
                            (string-append %backup-directory "/restic"))
           (backup-services 's3 %s3-repository
                            #:environment %s3-environment))))

%system
