(define-module (common system maintenance)
  #:use-module (guix gexp)
  #:use-module (gnu services)
  #:use-module (gnu services linux)
  #:use-module (gnu services networking)
  #:use-module (gnu services shepherd)
  #:use-module (gnu packages backup)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages package-management)
  #:export (%time-servers
            %maintenance-services
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

(define guix-gc-timer
  (simple-service 'guix-gc-timer shepherd-root-service-type
                  (list (shepherd-timer '(guix-gc)
                                        "0 12 * * *"
                                        #~(#$(file-append guix "/bin/guix")
                                           "gc" "--delete-generations=2w")
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
                     ;; Hourly, so that missed runs (machine off) don't matter;
                     ;; the preserve policy thins out the snapshots
                     (list (shepherd-timer '(btrbk)
                                           "0 * * * *"
                                           #~(#$(file-append btrbk "/bin/btrbk")
                                              "-c" #$config "run")
                                           #:requirement '(file-systems))
                           (shepherd-timer '(btrfs-scrub)
                                           "0 13 1 * *"
                                           #~(#$(file-append btrfs-progs "/bin/btrfs")
                                              "scrub" "start" "-B"
                                              #$scrub-mount-point)
                                           #:requirement '(file-systems)))))))

(define %maintenance-services
  (list ntp-service
        guix-gc-timer
        (service earlyoom-service-type)))
