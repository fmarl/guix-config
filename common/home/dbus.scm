;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common home dbus)
  #:use-module (guix gexp)
  #:use-module (gnu home services)
  #:use-module (gnu home services shells)
  #:use-module (gnu home services shepherd)
  #:use-module (gnu packages admin)
  #:use-module (guix-apparmor packages dbus)
  #:use-module (gnu services)
  #:export (%dbus-services))

(define dbus-shepherd-service
  (shepherd-service (provision '(dbus))
                    (modules '((shepherd support)))
                    (start #~(lambda _
                               (let* ((runtime-dir (or (getenv
                                                        "XDG_RUNTIME_DIR")
                                                       (format #f
                                                               "/run/user/~a"
                                                               (getuid))))
                                      (config (string-append runtime-dir
                                                             "/dbus.conf"))
                                      (pid-file (string-append runtime-dir
                                                               "/dbus.pid")))
                                 (call-with-output-file config
                                   (lambda (port)
                                     (format port
                                      "<!DOCTYPE busconfig PUBLIC \"-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN\"
 \"http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd\">
<busconfig>
  <include>~a</include>
  <pidfile>~a</pidfile>
</busconfig>~%"
                                      #$(file-append dbus-apparmor
                                         "/share/dbus-1/session.conf")
                                      pid-file)))
                                 ((make-forkexec-constructor (list #$(file-append
                                                                      dbus-apparmor
                                                                      "/bin/dbus-daemon")
                                                                   "--nofork"
                                                                   (string-append
                                                                    "--config-file="
                                                                    config)
                                                                   (string-append
                                                                    "--address=unix:path="
                                                                    runtime-dir
                                                                    "/bus"))
                                                             #:pid-file
                                                             pid-file
                                                             #:log-file (string-append
                                                                         %user-log-dir
                                                                         "/dbus.log"))))))
                    (stop #~(make-kill-destructor))
                    (documentation "D-Bus session bus")))

(define %dbus-services
  (list (simple-service 'dbus home-shepherd-service-type
                        (list dbus-shepherd-service))
        (simple-service 'dbus-address home-environment-variables-service-type
                        '(("DBUS_SESSION_BUS_ADDRESS" . "unix:path=${XDG_RUNTIME_DIR:-/run/user/$UID}/bus")))
        (simple-service 'dbus-ready home-shell-profile-service-type
                        (list (mixed-text-file "dbus-ready"
                               "if [ -S \"${XDG_RUNTIME_DIR:-/run/user/$UID}/shepherd/socket\" ]; then"
                               "\n  "
                               shepherd-for-home
                               "/bin/herd start dbus >/dev/null\n"
                               "fi\n")))))
