;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common system maintenance)
  #:use-module (guix gexp)
  #:use-module (gnu packages backup)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages package-management)
  #:use-module (gnu services)
  #:use-module (gnu services linux)
  #:use-module (gnu services networking)
  #:use-module (gnu services shepherd)
  #:use-module (common system filesystem)
  #:use-module (srfi srfi-26)
  #:export (%maintenance-services btrfs-maintenance-services))

(define ntp-service
  (service ntp-service-type
           (ntp-configuration (servers (list (ntp-server (type 'pool)
                                                         (address
                                                          "de.pool.ntp.org")
                                                         (options '("iburst"))))))))

(define (run-when-due name days command)
  "Run COMMAND unless it succeeded less than DAYS ago."
  (let ((stamp (string-append "/var/lib/catch-up/"
                              (symbol->string name))))
    (program-file (string-append (symbol->string name) "-when-due")
                  (with-imported-modules '((guix build utils))
                                         #~(begin
                                             (use-modules (guix build utils))

                                             (define (due?)
                                               (or (not (file-exists? #$stamp))
                                                   (> (- (current-time)
                                                         (stat:mtime (stat #$stamp)))
                                                      #$(* days 24 60 60))))

                                             (define (record-success)
                                               (mkdir-p (dirname #$stamp))
                                               (call-with-output-file #$stamp
                                                 (const #t)))

                                             (when (due?)
                                               (if (zero? (system* #$@command))
                                                   (record-success)
                                                   (exit 1))))))))

(define* (catch-up-timer name
                         command
                         #:key days
                         minute
                         (requirement '()))
  "Check hourly at MINUTE and run COMMAND if it last succeeded more than DAYS
ago, so that runs missed while the machine was off are caught up."
  (shepherd-timer (list name)
                  (string-append (number->string minute) " * * * *")
                  #~(#$(run-when-due name days command))
                  #:requirement requirement))

(define catch-up-timers
  (simple-service 'catch-up-timers shepherd-root-service-type
                  (list (catch-up-timer 'guix-gc
                                        (list (file-append guix "/bin/guix")
                                              "gc" "--delete-generations=2w")
                                        #:days 7
                                        #:minute 20
                                        #:requirement '(guix-daemon)))))

(define (btrbk-config subvolumes)
  (plain-file "btrbk.conf"
              (string-join `("timestamp_format long"
                             "snapshot_preserve_min 2d"
                             "snapshot_preserve 14d"
                             "snapshot_create onchange"
                             ""
                             ,(string-append "volume " %btrfs-top-level)
                             ,(string-append "  snapshot_dir "
                                             %snapshot-subvolume)
                             ,@(map (cut string-append "  subvolume " <>)
                                    subvolumes)) "\n"
                           'suffix)))

(define (btrfs-maintenance-services subvolumes)
  "Snapshots of the top level SUBVOLUMES via btrbk and a monthly scrub of the
btrfs file system."
  (let ((config (btrbk-config subvolumes)))
    (list (simple-service 'btrbk-config etc-service-type
                          `(("btrbk/btrbk.conf" ,config)))
          (simple-service 'btrfs-maintenance shepherd-root-service-type
                          (list (shepherd-timer '(btrbk) "0 * * * *"
                                                #~(#$(file-append btrbk
                                                      "/bin/btrbk")
                                                   "-c"
                                                   #$config "run")
                                                #:requirement '(file-systems))
                                (catch-up-timer 'btrfs-scrub
                                                (list (file-append btrfs-progs
                                                       "/bin/btrfs") "scrub"
                                                      "start" "-B"
                                                      %btrfs-top-level)
                                                #:days 30
                                                #:minute 50
                                                #:requirement '(file-systems)))))))

(define %maintenance-services
  (list ntp-service catch-up-timers
        (service earlyoom-service-type)))
