;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(use-modules ((gnu build file-systems)
              #:select (canonicalize-device-spec mount-file-system))
             (gnu system)
             (gnu system accounts)
             (gnu system file-systems)
             (gnu system mapped-devices)
             (gnu system uuid)
             ((guix read-print)
              #:select (pretty-print-with-comments))
             ((guix build syscalls)
              #:select (mount umount))
             ((guix build utils)
              #:select (invoke mkdir-p))
             (common build impermanence)
             (common system filesystem)
             (ice-9 match)
             (ice-9 rdelim)
             (rnrs bytevectors)
             (rnrs io ports)
             (srfi srfi-1)
             (srfi srfi-26))

(define (host-variable host module name)
  (module-ref (resolve-interface `(hosts ,(string->symbol host)
                                         ,module)) name))

(define (host-file-systems host)
  (host-variable host
                 'hardware
                 '%file-systems))

(define (top-level? fs)
  (string=? (file-system-mount-point fs) %btrfs-top-level))

(define (fact key . values)
  (format #t "~a~{ ~a~}~%" key values))

(define (device-fact device)
  (cond
    ((uuid? device)
     (fact 'btrfs
           'uuid
           (uuid->string device)))
    ((file-system-label? device)
     (fact 'btrfs
           'label
           (file-system-label->string device)))
    (else (fact 'btrfs
                'device device))))

(define (luks-fact device)
  (when (eq? (mapped-device-type device) luks-device-mapping)
    (match (mapped-device-source device)
      ((? uuid? source)
       (fact 'luks
             (uuid->string source)
             (first (mapped-device-targets device))))
      (source (error "LUKS source is no UUID:" source)))))

(define (layout-facts file-systems mapped-devices)
  (when (impermanent-file-systems? file-systems)
    (fact 'persist %persist))
  (for-each luks-fact mapped-devices)
  (for-each (lambda (fs)
              (cond
                ((top-level? fs)
                 (device-fact (file-system-device fs)))
                ((string=? (file-system-mount-point fs) "/boot/efi")
                 (fact 'esp
                       (uuid->string (file-system-device fs)))))) file-systems))

(define (user-names os)
  (filter-map (lambda (account)
                (and (not (user-account-system? account))
                     (not (string=? (user-account-name account) "root"))
                     (user-account-name account)))
              (operating-system-users os)))

(define (create-subvolumes file-systems)
  (let ((device (canonicalize-device-spec (file-system-device (find top-level?
                                                               file-systems))))
        (top (mkdtemp "/tmp/subvolumes-XXXXXX")))
    (mount device top "btrfs" 0 "subvolid=5")
    (dynamic-wind (const #t)
                  (lambda ()
                    (for-each (match-lambda
                                ((name . _) (invoke "btrfs" "subvolume"
                                                    "create"
                                                    (string-append top "/"
                                                                   name))))
                              (btrfs-subvolumes file-systems)))
                  (lambda ()
                    (umount top)
                    (rmdir top)))))

(define (installer-binds target)
  "Bind /var/guix and /tmp, where cow-store keeps the new store items, to
the persistent subvolume instead of the tmpfs root."
  (map (match-lambda
         ((source mount-point)
          (file-system
            (device (string-append target %persist source))
            (mount-point mount-point)
            (type "none")
            (flags '(bind-mount))
            (check? #f))))
       '(("/var/guix" "/var/guix")
         ("/var/tmp" "/tmp"))))

(define (mount-all file-systems target)
  (for-each (lambda (fs)
              (mount-file-system fs
                                 #:root target
                                 #:check? #f)) file-systems))

(define (mount-target file-systems target)
  (mount-all (sort (remove top-level? file-systems)
                   (lambda (a b)
                     (string<? (file-system-mount-point a)
                               (file-system-mount-point b)))) target)
  (when (impermanent-file-systems? file-systems)
    (let ((persist (string-append target %persist)))
      (mkdir-p (string-append persist "/var/guix"))
      (mkdir-p (string-append persist "/var/tmp"))
      (chmod (string-append persist "/var/tmp") #o1777)
      (mount-all (installer-binds target) target))))

(define (hash-password password)
  (define alphabet
    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789./")

  (let ((salt (call-with-input-file "/dev/urandom"
                (lambda (port)
                  (list->string (map (lambda (_)
                                       (string-ref alphabet
                                                   (modulo (get-u8 port) 64)))
                                     (iota 16))))
                #:binary #t)))
    (crypt password
           (string-append "$6$" salt "$"))))

(define (read-lines file)
  (call-with-input-file file
    (lambda (port)
      (let loop
        ((lines '()))
        (match (read-line port)
          ((? eof-object?)
           (reverse lines))
          (line (loop (cons line lines))))))))

(define (set-shadow-entry shadow user hash)
  (let ((others (if (file-exists? shadow)
                    (remove (cut string-prefix?
                                 (string-append user ":") <>)
                            (read-lines shadow))
                    '())))
    (mkdir-p (dirname shadow))
    (call-with-output-file shadow
      (lambda (port)
        (chmod port #o600)
        (for-each (cut format port "~a~%" <>) others)
        (format port "~a:~a:~a::::::~%" user hash
                (quotient (current-time) 86400))))))

(define (store-password-hash file-systems target user hash)
  (unless (string-prefix? "$" hash)
    (error "invalid password hash for" user))
  (if (impermanent-file-systems? file-systems)
      (save-password-hash (string-append target %persist) user hash)
      (set-shadow-entry (string-append target "/etc/shadow") user hash)))

(define (random-uuid)
  (call-with-input-file "/proc/sys/kernel/random/uuid"
    read-line))

(define (random-volume-id)
  (let ((hex (string-upcase (format #f "~{~2,'0x~}"
                                    (bytevector->u8-list (call-with-input-file "/dev/urandom"
                                                           (cut
                                                            get-bytevector-n
                                                            <> 4)
                                                           #:binary #t))))))
    (string-append (string-take hex 4) "-"
                   (string-drop hex 4))))

(define (host-module host name exports . modules)
  `(define-module (hosts ,host
                         ,name)
     ,@(append-map (cut list
                        #:use-module <>) modules)
     #:export ,exports))

(define (hardware-file host layout luks?)
  (list (host-module host
                     'hardware
                     '(%mapped-devices %file-systems)
                     '(gnu)
                     '(common system filesystem))
        `(define %mapped-devices
           ,(if luks?
                `(list (mapped-device
                         (source (uuid ,(random-uuid)))
                         (target "guix-root")
                         (type luks-device-mapping)
                         (arguments (list #:allow-discards? #t))))
                ''()))
        `(define %file-systems
           (,layout ,@(if luks?
                          '("/dev/mapper/guix-root")
                          `((uuid ,(random-uuid)
                                  'btrfs)))
            #:esp ,(random-volume-id)
            ,@(if luks?
                  '(#:dependencies %mapped-devices)
                  '())))))

(define (system-file host luks?)
  (list (host-module host
                     'system
                     '(%system)
                     '(gnu)
                     '(nongnu packages linux)
                     '(common machines)
                     '(common system base)
                     '(common system networking)
                     `(hosts ,host hardware))
        `(define %machine
           (lookup-machine ',host))
        `(define %system
           (base-operating-system %machine
                                  ,@(if luks?
                                        '(#:initrd-modules (cons "dm-crypt"
                                                                 (base-initrd-modules
                                                                  linux)))
                                        '())
                                  #:firmware (list linux-firmware)
                                  #:mapped-devices %mapped-devices
                                  #:file-systems %file-systems
                                  #:services (network-services %machine)))
        '%system))

(define (home-file host)
  (list (host-module host
                     'home
                     '(%home)
                     '(common home base)
                     '(common machines))
        `(define %machine
           (lookup-machine ',host))
        `(define %home
           (base-home-environment %machine
                                  #:services (append (desktop-services
                                                      %machine)
                                                     (secrets-services
                                                      %machine))))
        '%home))

(define (write-forms file forms)
  (call-with-output-file file
    (lambda (port)
      (display (string-join (map (lambda (form)
                                   (call-with-output-string (cut
                                                             pretty-print-with-comments
                                                             <> form))) forms)
                            "\n\n") port)
      (newline port))))

(define (generate-host host directory options)
  (let ((host (string->symbol host))
        (layout (if (member "impermanent" options)
                    'impermanent-file-systems
                    'btrfs-file-systems))
        (luks? (not (member "no-luks" options))))
    (write-forms (string-append directory "/hardware.scm")
                 (hardware-file host layout luks?))
    (write-forms (string-append directory "/system.scm")
                 (system-file host luks?))
    (write-forms (string-append directory "/home.scm")
                 (home-file host))))

(match (command-line)
  ((_ "layout" host)
   (layout-facts (host-file-systems host)
                 (host-variable host
                                'hardware
                                '%mapped-devices)))
  ((_ "generate" host directory . options) (generate-host host directory
                                                          options))
  ((_ "users" host)
   (for-each (cut format #t "~a~%" <>)
             (user-names (host-variable host
                                        'system
                                        '%system))))
  ((_ "create-subvolumes" host)
   (create-subvolumes (host-file-systems host)))
  ((_ "mount" host target)
   (mount-target (host-file-systems host) target))
  ((_ "hash-password")
   (display (hash-password (read-line)))
   (newline))
  ((_ "store-password-hash" host target user)
   (store-password-hash (host-file-systems host) target user
                        (read-line))))
