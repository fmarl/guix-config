;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common system maintenance)
  #:use-module (guix gexp)
  #:use-module (gnu services)
  #:use-module (gnu services linux)
  #:use-module (gnu services networking)
  #:use-module (gnu services shepherd)
  #:use-module (gnu packages backup)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages package-management)
  #:export (%maintenance-services
            btrfs-maintenance-services))

(define %time-servers
  '("0.de.pool.ntp.org"
    "1.de.pool.ntp.org"
    "2.de.pool.ntp.org"
    "3.de.pool.ntp.org"))

(define ntp-service
  (service ntp-service-type
           (ntp-configuration
            (servers (map (lambda (address)
                            (ntp-server (type 'pool)
                                        (address address)
                                        (options '("iburst"))))
                          %time-servers)))))

(define (run-when-due name days command)
  "Run COMMAND unless it succeeded less than DAYS ago."
  (let ((stamp (string-append "/var/lib/catch-up/" (symbol->string name))))
    (program-file
     (string-append (symbol->string name) "-when-due")
     (with-imported-modules '((guix build utils))
       #~(begin
           (use-modules (guix build utils))

           (define (due?)
             (or (not (file-exists? #$stamp))
                 (> (- (current-time) (stat:mtime (stat #$stamp)))
                    #$(* days 24 60 60))))

           (define (record-success)
             (mkdir-p (dirname #$stamp))
             (call-with-output-file #$stamp (const #t)))

           (when (due?)
             (if (zero? (system* #$@command))
                 (record-success)
                 (exit 1))))))))

(define* (catch-up-timer name command #:key days minute (requirement '()))
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
                                        #:days 7 #:minute 20
                                        #:requirement '(guix-daemon)))))

(define* (btrbk-config subvolumes #:key (preserve "14d"))
  (plain-file "btrbk.conf"
              (string-append
               "timestamp_format long
snapshot_preserve_min 2d
snapshot_preserve " preserve "
snapshot_create onchange

volume /
  snapshot_dir .snapshots
"
               (string-concatenate
                (map (lambda (subvolume)
                       (string-append "  subvolume " subvolume "\n"))
                     subvolumes)))))

(define* (btrfs-maintenance-services #:key
                                     (snapshot-subvolumes '("home"))
                                     (scrub-mount-point "/"))
  "Snapshots of SNAPSHOT-SUBVOLUMES (relative to /) in /.snapshots via btrbk
and a monthly scrub of the file system at SCRUB-MOUNT-POINT."
  (let ((config (btrbk-config snapshot-subvolumes)))
    (list
     (simple-service 'btrbk-config etc-service-type
                     `(("btrbk/btrbk.conf" ,config)))
     (simple-service 'btrfs-maintenance shepherd-root-service-type
                     (list (shepherd-timer '(btrbk)
                                           "0 * * * *"
                                           #~(#$(file-append btrbk "/bin/btrbk")
                                              "-c" #$config "run")
                                           #:requirement '(file-systems))
                           (catch-up-timer 'btrfs-scrub
                                           (list (file-append btrfs-progs "/bin/btrfs")
                                                 "scrub" "start" "-B"
                                                 scrub-mount-point)
                                           #:days 30 #:minute 50
                                           #:requirement '(file-systems)))))))

(define %maintenance-services
  (list ntp-service
        catch-up-timers
        (service earlyoom-service-type)))
