(define-module (my home desktop)
  #:use-module (guix gexp)
  #:use-module (gnu services)
  #:use-module (gnu home services shepherd)
  #:export (home-wayland-service-type))

;;;
;;; Waiting for Wayland.
;;;

(define (wayland-shepherd-service delay)
  (list (shepherd-service
         (provision '(wayland-display))
         (modules '((ice-9 ftw)
                    (ice-9 regex)
                    (ice-9 match)
                    (srfi srfi-1)
                    (shepherd support)))
         (start
          #~(lambda* (#:optional (env-wayland-display (getenv "WAYLAND_DISPLAY")))

              (define wayland-socket-regex "wayland-[0-9]+$")

              (define (find-socket directory regex)
                (find (match-lambda
                        ((or "." "..") #f)
                        (name
                         (let ((name (in-vicinity directory
                                                  name)))
                           (and (string-match regex name)
                                (access? name O_RDWR)))))
                      ;; Wayland names its sockets ‘wayland-n’. With
                      ;; ‘reverse’, we pick up on the last Wayland instance
                      ;; created (essentially what we always want to do).
                      (or (reverse (scandir directory)) '())))

              (define (find-display delay)
                (let loop ((attempts delay))

                  (define wayland-display
                    (or env-wayland-display
                        (find-socket %user-runtime-dir "wayland-[0-9]+$")))

                  (unless wayland-display
                    (unless (zero? attempts)
                      (sleep 1)
                      (loop (- attempts 1)))

                    (format (current-error-port)
                            "Wayland server did not show up; giving up.\n"))

                  wayland-display))
	      
	      (define wayland-display (find-display #$delay))

              (when wayland-display
                (format #t "Wayland display found at ~s.~%" wayland-display)
                ;; Note: 'make-forkexec-constructor' calls take their
                ;; default #:environment-variables value before this service
                ;; is started and are thus unaffected by the 'setenv' call
                ;; below.  Users of this service have to explicitly query
                ;; its value.
                (setenv "WAYLAND_DISPLAY" wayland-display))

              wayland-display))

         (stop #~(lambda (_)
                   (unsetenv "WAYLAND_DISPLAY")
                   #f))
         (respawn? #f))))

(define home-wayland-service-type
  (service-type
   (name 'home-wayland-display)
   (extensions (list (service-extension home-shepherd-service-type
                                        wayland-shepherd-service)))
   (default-value 10)
   (description
    "Create a @code{wayland-display} Shepherd service that waits for a Wayland
compositor to be up and running, up to a configurable delay, and sets the
@code{WAYLAND_DISPLAY} environment variable of @command{shepherd} itself
accordingly.  If no accessible Wayland server shows up during that time, the
@code{wayland-display} service is marked as failing to start.")))
