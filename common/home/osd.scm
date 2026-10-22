;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common home osd)
  #:use-module (guix gexp)
  #:use-module (gnu packages gnome)
  #:use-module (gnu packages linux)
  #:use-module (common home helpers)
  #:export (volume-osd
            brightness-osd))

(define (osd-script name file variables)
  "FILE sets $percent and $title for the notification."
  (shell-script-file name
                     (list file (local-file "files/osd.sh"))
                     #:variables
                     `(("osd_name" . ,name)
                       ("notify_send"
                        . ,(file-append libnotify "/bin/notify-send"))
                       ,@variables)))

(define volume-osd
  (osd-script "volume-osd"
              (local-file "files/volume-osd.sh")
              `(("wpctl" . ,(file-append wireplumber "/bin/wpctl")))))

(define brightness-osd
  (osd-script "brightness-osd"
              (local-file "files/brightness-osd.sh")
              `(("brightnessctl"
                 . ,(file-append brightnessctl "/bin/brightnessctl")))))
