;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(add-to-load-path (dirname (dirname (current-filename))))

(use-modules (common system test)
             (hosts workstation system))

(host-system-test 'workstation %system
                  #:services '(networking ssh-daemon unbound pcscd seatd)
                  #:apparmor-profiles '("librewolf"
                                        "signal-desktop"
                                        "syncthing")
                  #:open-tcp-ports '(22))
