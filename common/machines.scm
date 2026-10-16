;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common machines)
  #:use-module (guix records)
  #:use-module (common themes)
  #:use-module (srfi srfi-1)
  #:export (%lan-subnet %addressed-machines
                        lookup-machine
                        machine-name
                        machine-address
                        machine-interface
                        machine-gateway
                        machine-wm
                        machine-theme
                        machine-mobile?
                        machine-audio?
                        machine-syncthing-id))

(define %lan-subnet
  "192.168.0.0/24")

(define-record-type* <machine> machine make-machine
  machine?
  (name machine-name)
  (address machine-address
           (default #f))
  (interface machine-interface
             (default #f))
  (gateway machine-gateway
           (default #f))
  (wm machine-wm
      (default 'nucleotide))
  (theme machine-theme
         (default modus-operandi-tinted))
  (mobile? machine-mobile?
           (default #f))
  (audio? machine-audio?
          (default #t))
  (syncthing-id machine-syncthing-id
                (default #f)))

(define %machines
  (list (machine (name 'workstation)
                 (wm 'niri)
                 (theme ef-owl)
                 (address "192.168.0.200")
                 (interface "enp5s0")
                 (gateway "192.168.0.1")
                 (audio? #f)
                 (syncthing-id
                  "6E6JF2J-WMHAHHL-HPW7MXR-XCAKSWE-QH4XBGK-HVBIWRV-AFWMRQI-2E2L7QG"))
        (machine (name 'thinkpad)
                 (wm 'niri)
                 (mobile? #t)
                 (syncthing-id
                  "JBWKNB3-QHCRMWW-LABCNB5-R4VTXQI-3UVDZT3-7PXRCTB-YJL3CCA-HEDR7AG"))
        (machine (name 'fermion)
                 (address "192.168.0.201")
                 (interface "eth0")
                 (gateway "192.168.0.1")
                 (wm #f)
                 (syncthing-id
                  "RJLHUQJ-PZP6AZ2-UHRQNWJ-7AUYI45-WBKQ7IH-Z4XXWAF-2N55XM2-5IMSMAG"))
        (machine (name 'default))))

(define %addressed-machines
  (filter machine-address %machines))

(define (lookup-machine name)
  (or (find (lambda (machine)
              (eq? (machine-name machine) name)) %machines)
      (error "unknown machine" name)))
