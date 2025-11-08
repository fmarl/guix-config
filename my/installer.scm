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

;; Generate a bootable image (e.g. for USB sticks, etc.) with:
;; $ guix system image -t iso9660 installer.scm

(define-module (nongnu system install)
  #:use-module (guix)
  #:use-module (guix channels)
  #:use-module (gnu packages version-control)
  #:use-module (gnu packages vim)
  #:use-module (gnu packages curl)
  #:use-module (gnu packages emacs)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages mtools)
  #:use-module (gnu packages package-management)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu system)
  #:use-module (gnu system install)
  #:use-module (nongnu packages linux)
  #:export (installation-os-nonfree))

(define %channels
  (cons*
   (channel
    (name 'guix)
    (url "https://codeberg.org/guix/guix")
    ;; Enable signature verification:
    (introduction
     (make-channel-introduction
      "1fc71fd013a752600de04e3f5a5757fc1eafc5e7"
      (openpgp-fingerprint
       "2841 9AC6 5038 7440 C7E9  2FFA 2208 D209 58C1 DEB0"))))
   
   (channel
    (name 'nonguix)
    (url "https://gitlab.com/nonguix/nonguix")
    ;; Enable signature verification:
    (introduction
     (make-channel-introduction
      "897c1a470da759236cc11798f4e0a5f7d4d59fbc"
      (openpgp-fingerprint
       "2A39 3FFF 68F4 EF7A 3D29  12AF 6F51 20A0 22FB B2D5"))))
   %default-channels))

(define installation-os-nonfree
  (operating-system
    (inherit installation-os)
    (kernel linux)
    (firmware (list linux-firmware))

    ;; Add the 'net.ifnames' argument to prevent network interfaces
    ;; from having really long names.  This can cause an issue with
    ;; wpa_supplicant when you try to connect to a wifi network.
    (kernel-arguments '("net.ifnames=0"))

    (services
     (cons*
      (modify-services (operating-system-user-services installation-os)
        (guix-service-type
         config => (guix-configuration
                    (inherit config)
                    (guix (guix-for-channels %channels))
                    (channels %channels))))))

    ;; Add some extra packages useful for the installation process
    (packages
     (append (list git curl emacs-no-x-toolkit)
             (operating-system-packages installation-os)))))

installation-os-nonfree
