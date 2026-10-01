;;; Copyright © 2019 Alex Griffin <a@ajgrf.com>
;;; Copyright © 2019 Pierre Neidhardt <mail@ambrevar.xyz>
;;; Copyright © 2019,2024 David Wilson <david@daviwil.com>
;;; Copyright © 2022 Jonathan Brielmaier <jonathan.brielmaier@web.de>
;;; Copyright © 2024 Hilton Chain <hako@ultrarare.space>
;;;
;;; This program is free software: you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation, either version 3 of the License, or
;;; (at your option) any later version.
;;;
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;; Built with `make installer`.  The image uses the pinned channels and
;; contains this repository in /etc/guix-config.

(define-module (common system installer)
  #:use-module (guix)
  #:use-module (guix channels)
  #:use-module (gnu packages cryptsetup)
  #:use-module (gnu packages curl)
  #:use-module (gnu packages disk)
  #:use-module (gnu packages emacs)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages package-management)
  #:use-module (gnu packages version-control)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu system)
  #:use-module (gnu system install)
  #:use-module (nongnu packages linux)
  #:export (installation-os-nonfree))

(define %root
  (dirname (dirname (dirname (current-filename)))))

(define %channels
  (eval (call-with-input-file (string-append %root "/channels-lock.scm") read)
        (current-module)))

(define guix-config
  (local-file %root "guix-config"
              #:recursive? #t
              #:select? (lambda (file stat)
                          (not (string=? (basename file) ".git")))))

(define installation-os-nonfree
  (operating-system
    (inherit installation-os)
    (kernel linux)
    (firmware (list linux-firmware))

    ;; Prevent long interface names, wpa_supplicant has trouble with them
    (kernel-arguments '("net.ifnames=0"))

    (services
     (cons* (simple-service 'guix-config etc-service-type
                            `(("guix-config" ,guix-config)))
            (modify-services (operating-system-user-services installation-os)
              (guix-service-type config =>
                                 (guix-configuration
                                   (inherit config)
                                   (guix (guix-for-channels %channels))
                                   (channels %channels))))))

    (packages (append (list git curl emacs-no-x-toolkit
                            cryptsetup parted btrfs-progs dosfstools)
                      (operating-system-packages installation-os)))))

installation-os-nonfree
