;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common system desktop)
  #:use-module (guix gexp)
  #:use-module (ice-9 match)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu services dbus)
  #:use-module (gnu services desktop)
  #:use-module (gnu services firmware)
  #:use-module (gnu services xorg)
  #:use-module (gnu packages admin)
  #:use-module (gnu packages glib)
  #:use-module (gnu packages window-management)
  #:use-module (gnu packages zig-xyz)
  #:use-module (sagittarius packages wm)
  #:use-module (common machines)
  #:export (compositor-session
            desktop-session
            %niri-session
            %nucleotide-session
            %desktop-services))

(define tuigreet-cache-service
  (simple-service 'tuigreet-cache activation-service-type
                  #~(let ((dir "/var/cache/tuigreet")
                          (greeter (getpwnam "greeter")))
                      (unless (file-exists? dir)
                        (mkdir dir))
                      (chown dir (passwd:uid greeter) (passwd:gid greeter)))))

(define (greetd-services session)
  "Run tuigreet starting SESSION on tty1, plain shells on tty2-3."
  (define (shell-terminal vt)
    (greetd-terminal-configuration
      (terminal-vt (number->string vt))
      (default-session-command
        (greetd-agreety-session (command (greetd-user-session))))))

  (list (service greetd-service-type
                 (greetd-configuration
                   (greeter-supplementary-groups '("video" "input" "seat" "users"))
                   (terminals
                    (cons (greetd-terminal-configuration
                            (terminal-vt "1")
                            (terminal-switch #t)
                            (default-session-command
                              (program-file
                               "tuigreet"
                               #~(execl #$(file-append tuigreet "/bin/tuigreet")
                                        "tuigreet" "--time" "--remember"
                                        "--asterisks" "--cmd" #$session))))
                          (map shell-terminal (iota 2 2))))))
        tuigreet-cache-service
        (service mingetty-service-type
                 (mingetty-configuration (tty "tty8")))))

(define* (compositor-session package session-command
                             #:key desktop-name (extra-env '()))
  "Install PACKAGE and start SESSION-COMMAND (a list) as the graphical session."
  (cons* (simple-service 'compositor profile-service-type (list package))
         (service seatd-service-type)
         (greetd-services
          (greetd-user-session
            (command (file-append dbus "/bin/dbus-run-session"))
            (command-args (cons* "--dbus-daemon"
                                 (file-append dbus "/bin/dbus-daemon")
                                 session-command))
            (xdg-session-type "wayland")
            (extra-env `(("XDG_CURRENT_DESKTOP" . ,desktop-name)
                         ("XDG_SESSION_DESKTOP" . ,desktop-name)
                         ,@extra-env))))))

(define %niri-session
  ;; niri --session exports XDG_CURRENT_DESKTOP to the D-Bus activation
  ;; environment, which xdg-desktop-portal needs
  (compositor-session niri
                      (list (file-append niri "/bin/niri") "--session")
                      #:desktop-name "niri"))

(define %nucleotide-session
  (compositor-session river-0.4
                      (list (file-append river-0.4 "/bin/river")
                            "-c" (file-append nucleotide "/bin/nucleotide"))
                      #:desktop-name "river"
                      #:extra-env '(("XKB_DEFAULT_LAYOUT" . "us")
                                    ("XKB_DEFAULT_VARIANT" . "altgr-intl"))))

(define (desktop-session host-name)
  (match (machine-wm (lookup-machine host-name))
    ('niri %niri-session)
    ('nucleotide %nucleotide-session)))

(define %desktop-services
  (list fontconfig-file-system-service
        (service screen-locker-service-type
                 (screen-locker-configuration
                   (name "waylock")
                   (program (file-append waylock "/bin/waylock"))))
        (service polkit-service-type)
        (service rtkit-service-type)
        (service fwupd-service-type)
        (service dbus-root-service-type)))
