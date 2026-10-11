;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common build impermanence)
  #:use-module (guix build utils)
  #:use-module (ice-9 match)
  #:use-module (ice-9 popen)
  #:use-module (ice-9 rdelim)
  #:export (create-persisted-directories restore-secrets save-secrets))

(define (permissions class)
  (string->number (match class
                    ('shared "755")
                    ('private "700")
                    ('secret "600")
                    ('sticky "1777")) 8))

(define (ensure-directory directory class)
  (unless (file-exists? directory)
    (mkdir-p directory)
    (chmod directory
           (permissions class))))

(define (replace-file file write)
  (let ((new (string-append file ".new")))
    (write new)
    (rename-file new file)))

(define (copy-file-atomically source target)
  (replace-file target
                (lambda (new)
                  (copy-file source new)
                  (chmod new
                         (stat:perms (stat source))))))

(define (write-secret file text)
  (replace-file file
                (lambda (new)
                  (call-with-output-file new
                    (lambda (port)
                      (chmod port
                             (permissions 'secret))
                      (display text port)
                      (newline port))))))

(define (create-persisted-directories persist directories)
  (for-each (match-lambda
              ((directory class)
               (ensure-directory (string-append persist directory) class)))
            directories))

(define (hash-file persist user)
  (string-append persist "/etc/shadow.d/" user))

(define (shadow-hash shadow user)
  (call-with-input-file shadow
    (lambda (port)
      (let loop
        ()
        (match (read-line port)
          ((? eof-object?)
           #f)
          (line (match (string-split line #\:)
                  ((name hash . _) (if (string=? name user) hash
                                       (loop)))
                  (_ (loop)))))))))

(define (restore-password persist chpasswd user)
  (let ((file (hash-file persist user)))
    (when (file-exists? file)
      (let ((port (open-pipe* OPEN_WRITE chpasswd "-e")))
        (format port "~a:~a~%" user
                (call-with-input-file file
                  read-line))
        (close-pipe port)))))

(define (save-password persist shadow user)
  (let ((hash (shadow-hash shadow user))
        (file (hash-file persist user)))
    (when (and hash
               (string-prefix? "$" hash))
      (ensure-directory (dirname file)
                        'private)
      (write-secret file hash))))

(define (sync-signing-key persist etc key)
  (let ((live (string-append etc "/guix/" key))
        (saved (string-append persist "/etc/guix/" key)))
    (cond
      ((file-exists? saved)
       (copy-file-atomically saved live))
      ((file-exists? live)
       (ensure-directory (dirname saved)
                         'private)
       (copy-file-atomically live saved)))))

(define* (restore-secrets persist users
                          #:key chpasswd
                          (etc "/etc"))
  "Restore the store signing key and the password hashes of USERS from
PERSIST, or persist the signing key if it is not saved yet."
  (for-each (lambda (key)
              (sync-signing-key persist etc key))
            '("signing-key.pub" "signing-key.sec"))
  (for-each (lambda (user)
              (restore-password persist chpasswd user)) users))

(define* (save-secrets persist users
                       #:key (etc "/etc"))
  "Save the password hashes of USERS to PERSIST."
  (for-each (lambda (user)
              (save-password persist
                             (string-append etc "/shadow") user)) users))
