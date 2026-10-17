;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(add-to-load-path (dirname (dirname (current-filename))))

(use-modules (common system test)
             (hosts thinkpad system))

(host-system-test 'thinkpad
                  %system
                  #:services '(NetworkManager wpa-supplicant
                                              pcscd
                                              seatd
                                              bluetooth
                                              upower-daemon
                                              power-profiles-daemon
                                              acpid)
                  #:apparmor-profiles '("librewolf" "signal-desktop"
                                        "syncthing")
                  #:open-tcp-ports '())
