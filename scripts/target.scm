;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

;; Prepare the installation target of a host from its hardware.scm.  Run with:
;; guix repl -- scripts/target.scm create-subvolumes|mount|hash-password|store-password-hash ...

(use-modules ((gnu build file-systems)
              #:select (canonicalize-device-spec mount-file-system))
             (gnu system file-systems)
             ((guix build syscalls)
              #:select (mount umount))
             ((guix build utils)
              #:select (invoke mkdir-p))
             (common build impermanence)
             (common system filesystem)
             (ice-9 match)
             (ice-9 rdelim)
             (rnrs io ports)
             (srfi srfi-1)
             (srfi srfi-26))

(define (host-file-systems host)
  (module-ref (resolve-interface `(hosts ,(string->symbol host) hardware))
              '%file-systems))

(define (top-level? fs)
  (string=? (file-system-mount-point fs) %btrfs-top-level))

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

(match (command-line)
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
