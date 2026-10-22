;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common system desktop)
  #:use-module (guix gexp)
  #:use-module (gnu packages admin)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages window-management)
  #:use-module (gnu packages zig-xyz)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu services dbus)
  #:use-module (gnu services desktop)
  #:use-module (gnu services firmware)
  #:use-module (gnu services sysctl)
  #:use-module (gnu services xorg)
  #:use-module (gnu system keyboard)
  #:use-module (gnu system pam)
  #:use-module (gnu system privilege)
  #:use-module (sagittarius packages wm)
  #:use-module (common locale)
  #:use-module (common machines)
  #:use-module (guix-apparmor profiles)
  #:use-module (guix-apparmor services)
  #:use-module (common system security)
  #:use-module (common themes)
  #:use-module (ice-9 match)
  #:export (desktop-session
            %desktop-base-services))

(define tuigreet-cache-service
  (simple-service 'tuigreet-cache activation-service-type
                  #~(let ((dir "/var/cache/tuigreet")
                          (greeter (getpwnam "greeter")))
                      (mkdir-p dir)
                      (chown dir (passwd:uid greeter) (passwd:gid greeter)))))

(define %tuigreet-theme
  (string-join (map (match-lambda
                      ((part . color)
                       (string-append part "="
                                      (symbol->string (console-color color)))))
                    '(("container" . bg_0)
                      ("text" . fg_0)
                      ("greet" . fg_0)
                      ("input" . fg_0)
                      ("border" . br_blue)
                      ("title" . br_blue)
                      ("prompt" . br_blue)
                      ("button" . br_blue)
                      ("time" . dim_0)
                      ("action" . dim_0)))
               ";"))

(define (greetd-services session)
  "Run tuigreet starting SESSION on tty1, plain shells on tty2-3."
  (define (shell-terminal vt)
    (greetd-terminal-configuration
     (terminal-vt (number->string vt))
     (default-session-command
       (greetd-agreety-session
        (command (greetd-user-session))))))

  (list (service greetd-service-type
                 (greetd-configuration
                  (greeter-supplementary-groups
                   '("video" "input" "seat" "users"))
                  (terminals
                   (cons (greetd-terminal-configuration
                          (terminal-vt "1")
                          (terminal-switch #t)
                          (default-session-command
                            (program-file
                             "tuigreet"
                             #~(execl #$(file-append tuigreet "/bin/tuigreet")
                                      "tuigreet"
                                      "--time"
                                      "--remember"
                                      "--asterisks"
                                      "--theme" #$%tuigreet-theme
                                      "--cmd" #$session))))
                         (map shell-terminal (iota 2 2))))))
        tuigreet-cache-service
        (service mingetty-service-type
                 (mingetty-configuration
                  (tty "tty8")))))

(define* (compositor-session package session-command
                             #:key desktop-name (extra-env '()))
  "Install PACKAGE and run the list SESSION-COMMAND as the graphical session."
  (cons* (simple-service 'compositor profile-service-type
                         (list package))
         (service seatd-service-type)
         (greetd-services
          (greetd-user-session
           (command (car session-command))
           (command-args (cdr session-command))
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
  (compositor-session
   river
   (list (file-append river "/bin/river")
         "-c" (file-append nucleotide "/bin/nucleotide"))
   #:desktop-name "river"
   #:extra-env
   `(("XKB_DEFAULT_LAYOUT" . ,(keyboard-layout-name %keyboard-layout))
     ("XKB_DEFAULT_VARIANT" . ,(keyboard-layout-variant %keyboard-layout)))))

(define (desktop-session machine)
  (match (machine-wm machine)
    ('niri %niri-session)
    ('nucleotide %nucleotide-session)))

(define %fuse-services
  (list (udev-rules-service 'fuse fuse)
        (simple-service 'fusermount privileged-program-service-type
                        (list (privileged-program
                               (program (file-append fuse "/bin/fusermount3"))
                               (setuid? #t))))))

(define %desktop-base-services
  (cons* fontconfig-file-system-service
         (service screen-locker-service-type
                  (screen-locker-configuration
                   (name "swaylock")
                   (program (file-append swaylock "/bin/swaylock"))
                   (using-setuid? #f)))
         (service polkit-service-type)
         (service pam-limits-service-type
                  (list (pam-limits-entry "@audio" 'both 'rtprio 95)
                        (pam-limits-entry "@audio" 'both 'nice -19)
                        (pam-limits-entry "@audio" 'both 'memlock 4194304)))
         (service fwupd-service-type)
         (service dbus-root-service-type)
         (udev-rules-service 'brightnessctl brightnessctl)
         (udev-rules-service 'alsa-utils alsa-utils)
         (simple-service 'coredump-sysctl sysctl-service-type
                         '(("kernel.core_uses_pid" . "1")))
         (simple-service 'librewolf-apparmor apparmor-service-type
                         (list %librewolf-profile
                               %signal-desktop-profile))
         (append %fuse-services %security-token-services)))
