;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common syncthing)
  #:use-module (guix gexp)
  #:use-module (gnu services syncthing)
  #:use-module (common machines)
  #:export (%syncthing-port
            %syncthing-temporary-files
            syncthing-peer
            synced-folders-config
            syncthing-apparmor-profile))

(define %syncthing-port "22000")

(define %syncthing-temporary-files
  '(".syncthing.*.tmp"))

(define %synced-folders
  '("Pictures" "Documents" "Videos" "Music" "Org"))

(define* (syncthing-peer machine #:key dial?)
  (syncthing-device
   (id (machine-syncthing-id machine))
   (name (symbol->string (machine-name machine)))
   (addresses (if dial?
                  (list (string-append "tcp://" (machine-address machine)
                                       ":" %syncthing-port))
                  '("dynamic")))))

(define (synced-folders-config directory peers)
  (syncthing-config-file
   (folders (map (lambda (name)
                   (syncthing-folder
                    (id (string-downcase name))
                    (label name)
                    (path (string-append directory "/" name))
                    (devices peers)))
                 %synced-folders))
   (global-announce-enabled? #f)
   (local-announce-enabled? #f)
   (relays-enabled? #f)
   (nat-enabled? #f)
   (start-browser? #f)
   (gui-enabled? #f)
   (usage-reporting-accepted -1)
   (crash-reporting-enabled? #f)
   (auto-upgrade-interval-hours 0)))

(define (syncthing-apparmor-profile state-directory directory)
  (plain-file "syncthing-apparmor-profile"
              (format #f "\
abi <abi/5.0>,

include <tunables/global>

@{syncthing}=/gnu/store/*-syncthing-*/bin/syncthing
@{synced}={~a}

profile syncthing @{syncthing} {
  include <abstractions/base>
  include <abstractions/nameservice>

  network inet stream,
  network inet6 stream,
  network inet dgram,
  network inet6 dgram,
  network netlink raw,

  deny @{run}/dbus/system_bus_socket rw,

  /gnu/store/** mr,
  @{syncthing} ix,

  /etc/ r,
  /etc/mime.types r,

  @{PROC}/ r,
  owner @{PROC}/@{pid}/** r,
  @{PROC}/sys/** r,
  @{sys}/kernel/mm/transparent_hugepage/** r,
  @{sys}/fs/cgroup/** r,

  deny /{,var/}tmp/ r,

  owner ~a/ rw,
  owner ~a/** rwkl,
  owner ~a/ r,
  owner ~a/@{synced}/ rw,
  owner ~a/@{synced}/** rwkl,
}
"
                      (string-join %synced-folders ",")
                      state-directory state-directory
                      directory directory directory)))
