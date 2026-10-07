;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common system acpi)
  #:use-module (guix gexp)
  #:use-module (gnu packages linux)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu services shepherd)
  #:export (acpid-service-type))

(define lid-handler
  (program-file "lid-handler"
                #~(begin
                    (use-modules (ice-9 ftw)
                                 (ice-9 match)
                                 (ice-9 rdelim)
                                 (srfi srfi-1)
                                 (srfi srfi-26))

                    (define %lid-directory "/proc/acpi/button/lid")

                    (define (lid-closed? lid)
                      (let ((state (call-with-input-file
                                       (string-append %lid-directory "/" lid "/state")
                                     read-line)))
                        (and (string? state)
                             (string-contains state "closed"))))

                    (define (any-lid-closed?)
                      (any lid-closed?
                           (or (scandir %lid-directory
                                        (negate (cut member <> '("." ".."))))
                               '())))

                    (match (command-line)
                      ((_ "close")
                       (when (any-lid-closed?)
                         ;; Without logind swayidle misses the suspend, SIGUSR1
                         ;; makes it lock the screen right away
                         (when (zero? (status:exit-val
                                       (system* #$(file-append procps "/bin/pkill")
                                                "-USR1" "-x" "swayidle")))
                           (sleep 1))
                         (call-with-output-file "/sys/power/state"
                           (lambda (port)
                             (display "mem" port)))))
                      (_ #t)))))

(define acpi-lid-event
  (mixed-text-file "lid" "event=button/lid.*\n" "action=" lid-handler
                   " close\n"))

(define acpid-shepherd-service
  (shepherd-service
   (provision '(acpid))
   (documentation "ACPI event daemon")
   (start #~(make-forkexec-constructor
             (list #$(file-append acpid "/sbin/acpid")
                   "--foreground" "--netlink")
             #:environment-variables
             (list "PATH=/run/current-system/profile/bin")))
   (stop #~(make-kill-destructor))))

(define acpid-service-type
  (service-type (name 'acpid)
                (description "Run acpid with a handler that suspends when the
lid is closed.")
                (extensions
                 (list (service-extension shepherd-root-service-type
                                          (const (list acpid-shepherd-service)))
                       (service-extension etc-service-type
                                          (const `(("acpi/events/lid"
                                                    ,acpi-lid-event))))))
                (default-value #f)))
