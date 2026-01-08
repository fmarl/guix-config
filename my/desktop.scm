(define-module (my desktop)
  #:use-module (guix gexp)
  #:use-module (guix records)
  #:use-module (guix build utils)
  #:use-module (gnu services)
  #:use-module (gnu services xorg)
  #:use-module (gnu services base)
  #:use-module (gnu services desktop)
  #:use-module (gnu services sound)
  #:use-module (gnu services lightdm)
  #:use-module (gnu services dbus)
  #:use-module (gnu services shepherd)
  #:use-module (gnu packages wm)
  #:use-module (gnu packages zig-xyz)
  #:use-module (gnu packages suckless)
  #:use-module (gnu packages shells)
  #:use-module (gnu packages glib)
  #:use-module (gnu system keyboard)
  #:use-module (srfi srfi-1)
  #:use-module (ice-9 match)
  #:use-module (my utils)
  #:use-module (my security)
  #:export (mate-desktop-services river-desktop-services make-desktop))

;; Mingetty + Agetty

(define (make-mingetty+agetty-services)
  (list (service agetty-service-type
                 (agetty-configuration (extra-options '("-L")) ;no carrier detect
                                       (term "vt100")
                                       (tty #f) ;automatic
                                       (shepherd-requirement '(syslogd))))

        (service mingetty-service-type
                 (mingetty-configuration (tty "tty1")))
        (service mingetty-service-type
                 (mingetty-configuration (tty "tty2")))
        (service mingetty-service-type
                 (mingetty-configuration (tty "tty3")))
        (service mingetty-service-type
                 (mingetty-configuration (tty "tty4")))
        (service mingetty-service-type
                 (mingetty-configuration (tty "tty5")))
        (service mingetty-service-type
                 (mingetty-configuration (tty "tty6")))))

;; Greetd

(define (make-greetd-login-manager-services default-runner-command)
  (define (make-runner run-command num)
    (greetd-terminal-configuration (terminal-vt num)
                                   (terminal-switch #t)
                                   (default-session-command (greetd-agreety-session
                                                             (command (greetd-user-session
                                                                       (command
                                                                        (file-append
                                                                         dbus
                                                                         "/bin/dbus-run-session"))
                                                                       (command-args
                                                                        (list
                                                                         run-command))))))))

  (define (make-terminal num)
    (greetd-terminal-configuration (terminal-vt num)
                                   (default-session-command (greetd-agreety-session
                                                             (command (greetd-user-session))))))

  (list (service greetd-service-type
                 (greetd-configuration (greeter-supplementary-groups '("video"
                                                                       "input"
                                                                       "seat"
                                                                       "users"))
                                       (terminals (list (make-runner
                                                         default-runner-command
                                                         "1")
                                                        (make-terminal "2")
                                                        (make-terminal "3")
                                                        (make-terminal "4")
                                                        (make-terminal "5")
                                                        (make-terminal "6")
                                                        (make-terminal "7")))))

        (service mingetty-service-type
                 (mingetty-configuration (tty "tty8")))))

;; River

(define-record-type* <river-desktop-configuration> river-desktop-configuration
                     make-river-desktop-configuration
  river-desktop-configuration?
  (river-package river-package
                 (default river)))

(define river-desktop-service-type
  (service-type (name 'river-desktop)
                (description "The river window manager")
                (extensions (list (service-extension profile-service-type
                                                     (compose list
                                                              river-package))))
                (default-value (river-desktop-configuration))))

(define river-desktop-services
  (cons* (service river-desktop-service-type)
         (service seatd-service-type)
         (make-greetd-login-manager-services "river")))

;; Niri

(define-record-type* <niri-desktop-configuration> niri-desktop-configuration
                     make-niri-desktop-configuration
  niri-desktop-configuration?
  (niri-package niri-package
                (default niri)))

(define niri-desktop-service-type
  (service-type (name 'niri-desktop)
                (description "The niri window manager")
                (extensions (list (service-extension profile-service-type
                                                     (compose list
                                                              niri-package))))
                (default-value (niri-desktop-configuration))))

(define niri-desktop-services
  (cons* (service niri-desktop-service-type)
         (service seatd-service-type)
         (make-greetd-login-manager-services "niri")))

;; Mate

(define mate-desktop-services
  (cons* (service mate-desktop-service-type)
         (service elogind-service-type)
         (make-mingetty+agetty-services)))

(define* (make-desktop #:key (desktop-services niri-desktop-services))
  (append desktop-services %security-services
          (list fontconfig-file-system-service

                ;; Screen Locking
                (service screen-locker-service-type
                         (screen-locker-configuration (name "waylock")
                                                      (program (file-append
                                                                waylock
                                                                "/bin/waylock"))))

                ;; D-Bus stuff
                (service dbus-root-service-type))))
