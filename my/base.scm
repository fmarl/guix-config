(define-module (my base)
  #:use-module (guix gexp)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu services shepherd)
  #:use-module (gnu services admin)
  #:use-module (gnu services sysctl)
  #:use-module (gnu packages base)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages bash)
  #:export (%my-base-services))


(define %my-base-services
  ;; Convenience variable holding the basic services.
  (list (service login-service-type)

        (service virtual-terminal-service-type)
        (service console-font-service-type
                 (map (lambda (tty)
                        (cons tty %default-console-font))
                      '("tty1" "tty2" "tty3" "tty4" "tty5" "tty6")))

        (service shepherd-system-log-service-type)


        ;; Extra Bash configuration including Bash completion and aliases.
        (service etc-bashrc-d-service-type)
        (service urandom-seed-service-type)
	
        (service guix-service-type)
        (service nscd-service-type)
	
        (service log-rotation-service-type)

        ;; Convenient services brought by the Shepherd.
        (service shepherd-timer-service-type)
        (service shepherd-transient-service-type)

        ;; Periodically delete old build logs.
        (service log-cleanup-service-type
                 (log-cleanup-configuration
                   (directory "/var/log/guix/drvs")))

        ;; The LVM2 rules are needed as soon as LVM2 or the device-mapper is
        ;; used, so enable them by default.  The FUSE and ALSA rules are
        ;; less critical, but handy.
        (service udev-service-type
                 (udev-configuration
                   (rules (list lvm2 fuse alsa-utils crda))))

        (service sysctl-service-type)

        (service special-files-service-type
                 `(("/bin/sh" ,(file-append bash "/bin/sh"))
                   ("/usr/bin/env" ,(file-append coreutils "/bin/env"))))))
