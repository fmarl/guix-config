(define-module (my acpi)
  #:use-module (guix gexp)
  #:use-module (gnu packages linux)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu services shepherd)
  #:export (acpid-service-type acpi-files-service-type))

(define lid-handler
  (program-file
   "lid-handler"
   #~(begin
       (use-modules (ice-9 match)
                    (ice-9 popen)
                    (ice-9 rdelim))

       (define (lid-closed?)
         (let* ((port (open-input-pipe
                       "cat /proc/acpi/button/lid/*/state"))
                (state (read-line port)))
           (close-pipe port)
           (and state
                (string-contains state "closed"))))

       (match (command-line)
         ((_ "close")
          (when (lid-closed?)
            (call-with-output-file "/sys/power/state"
              (lambda (port)
                (display "mem" port)))))
         (_ #t)))))

(define acpi-lid-event
  (mixed-text-file
   "lid"
   "event=button/lid.*\n"
   "action="
   lid-handler
   " close\n"))

(define acpid-shepherd-service
  (shepherd-service
   (provision '(acpid))
   (documentation "ACPI event daemon")
   (start #~(make-forkexec-constructor
             (list #$(file-append acpid "/sbin/acpid")
                   "--foreground"
                   "--netlink")
             #:environment-variables
             (list "PATH=/run/current-system/profile/bin")))
   (stop #~(make-kill-destructor))))

(define acpid-service-type
  (service-type
   (name 'acpid)
   (description "ACPI daemon")
   (extensions
    (list (service-extension shepherd-root-service-type
			     (const
			      (list acpid-shepherd-service)))))
   (default-value '())))

(define acpi-files-service-type
  (service-type
   (name 'acpi-files)
   (description "Providing ACPI related files")
   (extensions
    (list
     (service-extension etc-service-type
			(const
			 `(("acpi/events/lid" ,acpi-lid-event))))))
   (default-value '())))
