;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common system backup)
  #:use-module (guix build-system copy)
  #:use-module (guix gexp)
  #:use-module (guix packages)
  #:use-module (gnu packages backup)
  #:use-module (gnu services)
  #:use-module (gnu services shepherd)
  #:use-module (guix-impermanence services)
  #:use-module (common system maintenance)
  #:export (%restic-directory
            restic-services))

(define %restic-directory "/etc/restic")

(define %restic-cache-directory "/var/cache/restic")

(define (restic-command name repository environment)
  (program-file
   (string-append "restic-" (symbol->string name))
   #~(begin
       (use-modules (ice-9 match))
       (for-each (match-lambda
                   ((key . value)
                    (setenv key value)))
                 '#$(append
                     (list (cons "RESTIC_REPOSITORY" repository)
                           (cons "RESTIC_PASSWORD_FILE"
                                 (string-append %restic-directory "/password"))
                           (cons "RESTIC_CACHE_DIR" %restic-cache-directory))
                     environment))
       (apply execl #$(file-append restic "/bin/restic") "restic"
              (cdr (command-line))))))

(define (command-package command)
  (let ((name (program-file-name command)))
    (package
      (name name)
      (version "0")
      (source command)
      (build-system copy-build-system)
      (arguments
       (list #:install-plan #~'((#$name "bin/"))))
      (home-page #f)
      (synopsis #f)
      (description #f)
      (license #f))))

(define* (restic-services name repository files
                          #:key (environment '()) (excludes '()))
  (let ((command (restic-command name repository environment)))
    (define* (timer action arguments #:key days minute)
      (catch-up-timer (symbol-append 'restic- name '- action)
                      `(,command ,(symbol->string action) "--retry-lock" "1h"
                                 ,@arguments)
                      #:days days
                      #:minute minute
                      #:requirement '(file-systems)))

    (list (simple-service (symbol-append 'restic- name '-command)
                          profile-service-type
                          (list (command-package command)))
          (simple-service (symbol-append 'restic- name '-state)
                          persisted-directories-service-type
                          `((,%restic-directory #o700)
                            (,%restic-cache-directory #o700)))
          (simple-service (symbol-append 'restic- name '-timers)
                          shepherd-root-service-type
                          (list (timer 'backup
                                       (append (map (lambda (pattern)
                                                      (string-append
                                                       "--exclude=" pattern))
                                                    excludes)
                                               files)
                                       #:days 1
                                       #:minute 10)
                                (timer 'forget
                                       '("--prune"
                                         "--keep-daily" "7"
                                         "--keep-weekly" "4"
                                         "--keep-monthly" "12")
                                       #:days 7
                                       #:minute 20)
                                (timer 'check
                                       '("--read-data")
                                       #:days 30
                                       #:minute 30))))))
