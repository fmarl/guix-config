;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(add-to-load-path (dirname (dirname (current-filename))))

(use-modules (common system test)
             (hosts fermion system))

(host-system-test 'fermion %system
                  #:services '(networking
                               ssh-daemon
                               unbound
                               syncthing-syncthing)
                  #:apparmor-profiles '("syncthing")
                  #:open-tcp-ports '(22 22000))
