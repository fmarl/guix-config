;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common build impermanence)
  #:use-module (guix build utils)
  #:use-module (ice-9 ftw)
  #:use-module (ice-9 match)
  #:use-module (ice-9 popen)
  #:use-module (ice-9 rdelim)
  #:use-module (srfi srfi-1)
  #:use-module (srfi srfi-26)
  #:export (create-persisted-directories restore-secrets save-secrets
                                         save-password-hash))

(define (ensure-directory directory mode)
  (unless (file-exists? directory)
    (mkdir-p directory)
    (chmod directory mode)))

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
                      (chmod port #o600)
                      (display text port)
                      (newline port))))))

(define (create-persisted-directories persist directories)
  (for-each (match-lambda
              ((directory mode)
               (ensure-directory (string-append persist directory) mode)))
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

(define (save-password-hash persist user hash)
  (let ((file (hash-file persist user)))
    (ensure-directory (dirname file) #o700)
    (write-secret file hash)))

(define (save-password persist shadow user)
  (let ((hash (shadow-hash shadow user)))
    (when (and hash
               (string-prefix? "$" hash))
      (save-password-hash persist user hash))))

(define (sync-secret persist etc file)
  (let ((live (string-append etc "/" file))
        (saved (string-append persist "/etc/" file)))
    (cond
      ((file-exists? saved)
       (copy-file-atomically saved live))
      ((file-exists? live)
       (ensure-directory (dirname saved) #o700)
       (copy-file-atomically live saved)))))

(define (host-key-files persist etc)
  (define (host-keys directory)
    (or (scandir directory
                 (cut string-prefix? "ssh_host_" <>))
        '()))

  (let ((live (string-append etc "/ssh")))
    (if (file-exists? live)
        (map (cut string-append "ssh/" <>)
             (delete-duplicates (append (host-keys live)
                                        (host-keys (string-append persist
                                                                  "/etc/ssh")))))
        '())))

(define* (restore-secrets persist users
                          #:key chpasswd
                          (etc "/etc"))
  "Restore the store signing key, the SSH host keys and the password hashes
of USERS from PERSIST, or persist the keys that are not saved yet."
  (for-each (cut sync-secret persist etc <>)
            (append '("guix/signing-key.pub" "guix/signing-key.sec")
                    (host-key-files persist etc)))
  (for-each (lambda (user)
              (restore-password persist chpasswd user)) users))

(define* (save-secrets persist users
                       #:key (etc "/etc"))
  (for-each (lambda (user)
              (save-password persist
                             (string-append etc "/shadow") user)) users))
