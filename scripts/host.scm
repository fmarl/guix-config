;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(use-modules ((gnu build file-systems)
              #:select (canonicalize-device-spec mount-file-system))
             (gnu system)
             (gnu system accounts)
             (gnu system file-systems)
             (gnu system mapped-devices)
             (gnu system uuid)
             ((guix build syscalls)
              #:select (mount umount))
             ((guix build utils)
              #:select (invoke mkdir-p))
             (guix-impermanence build persist)
             (common users)
             (common system filesystem)
             (ice-9 match)
             (ice-9 rdelim)
             (rnrs bytevectors)
             (rnrs io ports)
             (srfi srfi-1)
             (srfi srfi-26))

(define (host-variable host module name)
  (module-ref (resolve-interface `(hosts ,(string->symbol host) ,module))
              name))

(define (host-file-systems host)
  (host-variable host 'hardware '%file-systems))

(define (top-level? fs)
  (string=? (file-system-mount-point fs) %btrfs-top-level))

(define (fact key . values)
  (format #t "~a~{ ~a~}~%" key values))

(define (device-fact device)
  (cond
   ((uuid? device)
    (fact 'btrfs 'uuid (uuid->string device)))
   ((file-system-label? device)
    (fact 'btrfs 'label (file-system-label->string device)))
   (else
    (fact 'btrfs 'device device))))

(define (luks-fact device)
  (when (eq? (mapped-device-type device) luks-device-mapping)
    (match (mapped-device-source device)
      ((? uuid? source)
       (fact 'luks
             (uuid->string source)
             (first (mapped-device-targets device))))
      (source
       (error "LUKS source is no UUID:" source)))))

(define (layout-facts file-systems mapped-devices)
  (when (impermanent-file-systems? file-systems)
    (fact 'persist %persist))
  (for-each luks-fact mapped-devices)
  (for-each (lambda (fs)
              (cond
               ((top-level? fs)
                (device-fact (file-system-device fs)))
               ((string=? (file-system-mount-point fs) "/boot/efi")
                (fact 'esp (uuid->string (file-system-device fs))))))
            file-systems))

(define (user-names os)
  (filter-map (lambda (account)
                (and (not (user-account-system? account))
                     (not (string=? (user-account-name account) "root"))
                     (user-account-name account)))
              (operating-system-users os)))

(define (create-subvolumes file-systems)
  (let ((device (canonicalize-device-spec
                 (file-system-device (find top-level? file-systems))))
        (top (mkdtemp "/tmp/subvolumes-XXXXXX")))
    (mount device top "btrfs" 0 "subvolid=5")
    (chmod top #o700)
    (dynamic-wind
      (const #t)
      (lambda ()
        (for-each (match-lambda
                    ((name . _)
                     (invoke "btrfs" "subvolume" "create"
                             (string-append top "/" name))))
                  (btrfs-subvolumes file-systems)))
      (lambda ()
        (umount top)
        (rmdir top)))))

(define (installer-binds target)
  "Bind /var/guix to the persistent subvolume and /tmp, where cow-store keeps
the new store items, to /var/tmp instead of the tmpfs root."
  (map (match-lambda
         ((source mount-point)
          (file-system
            (device (string-append target source))
            (mount-point mount-point)
            (type "none")
            (flags '(bind-mount))
            (check? #f))))
       `((,(string-append %persist "/var/guix") "/var/guix")
         ("/var/tmp" "/tmp"))))

(define (mount-all file-systems target)
  (for-each (lambda (fs)
              (mount-file-system fs #:root target #:check? #f))
            file-systems))

(define (mount-target file-systems target)
  (mount-all (sort (remove top-level? file-systems)
                   (lambda (a b)
                     (string<? (file-system-mount-point a)
                               (file-system-mount-point b))))
             target)
  (chmod (string-append target "/var/tmp") #o1777)
  (mkdir-p (string-append target %persist "/var/guix"))
  (mount-all (installer-binds target) target))

(define (hash-password password)
  (define alphabet
    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789./")

  (let ((salt (call-with-input-file "/dev/urandom"
                (lambda (port)
                  (list->string
                   (map (lambda (_)
                          (string-ref alphabet (modulo (get-u8 port) 64)))
                        (iota 16))))
                #:binary #t)))
    (crypt password (string-append "$6$" salt "$"))))

(define (store-password-hash target user hash)
  (unless (string-prefix? "$" hash)
    (error "invalid password hash for" user))
  (save-password-hash (string-append target %persist) user hash))

(define (random-uuid)
  (call-with-input-file "/proc/sys/kernel/random/uuid" read-line))

(define (random-volume-id)
  (let ((hex (string-upcase
              (format #f "~{~2,'0x~}"
                      (bytevector->u8-list
                       (call-with-input-file "/dev/urandom"
                         (cut get-bytevector-n <> 4)
                         #:binary #t))))))
    (string-append (string-take hex 4) "-" (string-drop hex 4))))

(define (hardware-file host luks?)
  (format #f "\
(define-module (hosts ~a hardware)
  #:use-module (gnu)
  #:use-module (common system filesystem)
  #:export (%mapped-devices
            %file-systems))

~a"
          host
          (if luks?
              (format #f "\
(define %mapped-devices
  (list (mapped-device
          (source (uuid ~s))
          (target \"guix-root\")
          (type luks-device-mapping)
          (arguments (list #:allow-discards? #t)))))

(define %file-systems
  (impermanent-file-systems \"/dev/mapper/guix-root\"
                            #:esp ~s
                            #:dependencies %mapped-devices))
"
                      (random-uuid)
                      (random-volume-id))
              (format #f "\
(define %mapped-devices '())

(define %file-systems
  (impermanent-file-systems
   (uuid ~s 'btrfs)
   #:esp ~s))
"
                      (random-uuid)
                      (random-volume-id)))))

(define (system-file host luks?)
  (format #f "\
(define-module (hosts ~a system)
  #:use-module (gnu)
  #:use-module (nongnu packages linux)
  #:use-module (common machines)
  #:use-module (common system base)
  #:use-module (hosts ~a hardware)
  #:export (%system))

(define %machine
  (lookup-machine '~a))

(define %system
  (base-operating-system
   %machine
~a   #:firmware (list linux-firmware)
   #:mapped-devices %mapped-devices
   #:file-systems %file-systems))

%system
"
          host host host
          (if luks?
              "   #:initrd-modules (cons \"dm-crypt\" \
(base-initrd-modules linux))\n"
              "")))

(define (home-file host)
  (format #f "\
(define-module (hosts ~a home)
  #:use-module (common home base)
  #:use-module (common machines)
  #:export (%home))

(define %machine
  (lookup-machine '~a))

(define %home
  (base-home-environment %machine))

%home
"
          host host))

(define (write-host-file file text)
  (call-with-output-file file
    (lambda (port)
      (format port "\
;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © ~a ~a <~a>

~a"
              (strftime "%Y" (localtime (current-time)))
              (user-full-name %user)
              (user-email %user)
              text))))

(define (generate-host host directory options)
  (let ((luks? (not (member "no-luks" options))))
    (write-host-file (string-append directory "/hardware.scm")
                     (hardware-file host luks?))
    (write-host-file (string-append directory "/system.scm")
                     (system-file host luks?))
    (write-host-file (string-append directory "/home.scm")
                     (home-file host))))

(match (command-line)
  ((_ "layout" host)
   (layout-facts (host-file-systems host)
                 (host-variable host 'hardware '%mapped-devices)))
  ((_ "generate" host directory . options)
   (generate-host host directory options))
  ((_ "users" host)
   (for-each (cut format #t "~a~%" <>)
             (user-names (host-variable host 'system '%system))))
  ((_ "create-subvolumes" host)
   (create-subvolumes (host-file-systems host)))
  ((_ "mount" host target)
   (mount-target (host-file-systems host) target))
  ((_ "hash-password")
   (display (hash-password (read-line)))
   (newline))
  ((_ "store-password-hash" target user)
   (store-password-hash target user (read-line))))
