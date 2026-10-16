;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common system syncthing)
  #:use-module (guix gexp)
  #:use-module (gnu packages admin)
  #:use-module (gnu packages base)
  #:use-module (gnu services)
  #:use-module (gnu services shepherd)
  #:use-module (gnu services syncthing)
  #:use-module (gnu system accounts)
  #:use-module (gnu system shadow)
  #:use-module (common machines)
  #:use-module (guix-apparmor services)
  #:use-module (common syncthing)
  #:use-module (ice-9 match)
  #:export (%syncthing-state-directory syncthing-server-services))

(define %syncthing-user
  "syncthing")

(define %syncthing-id
  800)

(define %syncthing-state-directory
  "/var/lib/syncthing")

(define syncthing-accounts
  (list (user-group
          (name %syncthing-user)
          (id %syncthing-id)
          (system? #t))
        (user-account
          (name %syncthing-user)
          (uid %syncthing-id)
          (group %syncthing-user)
          (system? #t)
          (comment "Syncthing")
          (home-directory "/var/empty")
          (create-home-directory? #f)
          (shell (file-append shadow "/sbin/nologin")))))

(define (config-xml config)
  (match (syncthing-files-service (syncthing-configuration (user
                                                            %syncthing-user)
                                                           (config-file config)))
    (((_ file))
     file)))

(define (syncthing-setup-service directory)
  (let ((chown (file-append coreutils "/bin/chown"))
        (owner (string-append %syncthing-user ":" %syncthing-user))
        (config (string-append %syncthing-state-directory "/config.xml")))
    (shepherd-service (provision '(syncthing-setup))
                      (requirement '(file-systems))
                      (one-shot? #t)
                      (start #~(lambda _
                                 (false-if-exception (delete-file #$config))
                                 (and (zero? (system* #$chown "-R" #$owner
                                                      #$%syncthing-state-directory))
                                      (zero? (system* #$chown #$owner
                                                      #$directory))
                                      (begin
                                        (symlink "/etc/syncthing/config.xml"
                                                 #$config) #t))))
                      (documentation
                       "Hand the keys and synced folders to the Syncthing user
and link its configuration"))))

(define (syncthing-server-services directory clients)
  (list (simple-service 'syncthing-accounts account-service-type
                        syncthing-accounts)
        (simple-service 'syncthing-config etc-service-type
                        `(("syncthing/config.xml" ,(config-xml (synced-folders-config
                                                                directory
                                                                (map (compose
                                                                      syncthing-peer
                                                                      lookup-machine)
                                                                     clients))))))
        (simple-service 'syncthing-setup shepherd-root-service-type
                        (list (syncthing-setup-service directory)))
        (simple-service 'syncthing-setup-before-syncthing
                        user-processes-service-type
                        '(syncthing-setup))
        (simple-service 'syncthing-apparmor apparmor-service-type
                        (list (syncthing-apparmor-profile
                               %syncthing-state-directory directory)))
        (service syncthing-service-type
                 (syncthing-configuration (user %syncthing-user)
                                          (group %syncthing-user)
                                          (arguments (list (string-append
                                                            "--home="
                                                            %syncthing-state-directory)))))))
