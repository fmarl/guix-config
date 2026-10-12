;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common system impermanence)
  #:use-module (guix gexp)
  #:use-module (gnu packages admin)
  #:use-module (gnu services)
  #:use-module (gnu services shepherd)
  #:use-module (gnu system file-systems)
  #:use-module (common system filesystem)
  #:use-module (ice-9 match)
  #:export (persisted-file-systems impermanence-services))

(define %persisted-directories
  '(("/var/guix" #o755)
    ("/root/.cache/guix" #o700)
    ("/var/lib/catch-up" #o755)
    ("/var/lib/bluetooth" #o700)
    ("/var/lib/NetworkManager" #o700)
    ("/etc/NetworkManager/system-connections" #o700)))

(define %build-modules
  '((guix build utils)
    (common build impermanence)))

(define (persisted-directories file-systems host-directories)
  (cond
    ((impermanent-file-systems? file-systems)
     (append %persisted-directories host-directories))
    ((null? host-directories)
     '())
    (else (error "persisted directories need impermanent-file-systems"
                 host-directories))))

(define (persisted-file-systems file-systems host-directories)
  (map (match-lambda
         ((directory _)
          (file-system
            (mount-point directory)
            (device (string-append %persist directory))
            (type "none")
            (flags '(bind-mount))
            (check? #f))))
       (persisted-directories file-systems host-directories)))

(define (persisted-directories-activation directories)
  (with-imported-modules %build-modules
                         #~(begin
                             (use-modules (common build impermanence))
                             (create-persisted-directories #$%persist
                                                           '#$directories))))

(define (secrets-program name exp)
  (program-file name
                (with-imported-modules %build-modules
                                       #~(begin
                                           (use-modules (common build
                                                                impermanence))
                                           #$exp))))

(define (persistent-secrets-shepherd-service users)
  (let ((restore (secrets-program "restore-secrets"
                                  #~(restore-secrets #$%persist
                                                     '#$users
                                                     #:chpasswd #$(file-append
                                                                   shadow
                                                                   "/sbin/chpasswd"))))
        (save (secrets-program "save-secrets"
                               #~(save-secrets #$%persist
                                               '#$users))))
    (shepherd-service (provision '(persistent-secrets))
                      (requirement '(file-systems))
                      (start #~(lambda _
                                 (system* #$restore) #t))
                      (stop #~(lambda _
                                (system* #$save) #f))
                      (documentation
                       "Persistent password hashes and signing key"))))

(define (impermanence-services file-systems host-directories users)
  (if (impermanent-file-systems? file-systems)
      (list (simple-service 'persisted-directories activation-service-type
                            (persisted-directories-activation (persisted-directories
                                                               file-systems
                                                               host-directories)))
            (simple-service 'persistent-secrets shepherd-root-service-type
                            (list (persistent-secrets-shepherd-service users)))
            (simple-service 'persistent-secrets-before-login
                            user-processes-service-type
                            '(persistent-secrets)))
      '()))
