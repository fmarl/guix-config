;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common home osd)
  #:use-module (guix gexp)
  #:use-module (gnu packages gnome)
  #:use-module (gnu packages linux)
  #:use-module (common home helpers)
  #:export (volume-osd brightness-osd))

(define (osd-script name . text)
  "Return a script that runs TEXT, which sets $percent and $title, and shows
them as a progress notification replacing the previous one."
  (apply shell-script name
         (append text
                 (list "id_file=\"$XDG_RUNTIME_DIR/" name
                  "\"\nid=$(cat \"$id_file\" 2>/dev/null)\n"
                  (file-append libnotify "/bin/notify-send")
                  " -a osd -u low -t 1500 -p -h \"int:value:${percent:-0}\" \\
    -r \"${id:-0}\" \"$title\" >\"$id_file.$$\" &&
    mv \"$id_file.$$\" \"$id_file\"
rm -f \"$id_file.$$\"
"))))

(define volume-osd
  (let ((wpctl (file-append wireplumber "/bin/wpctl")))
    (osd-script "volume-osd" wpctl " \"$@\"\nvolume=$(" wpctl
     " get-volume \"$2\")
percent=$(echo \"$volume\" | awk '{ print int($2 * 100 + 0.5) }')
case \"$2\" in
    *SOURCE*) title=Mikrofon ;;
    *) title=Lautstärke ;;
esac
case \"$volume\" in
    *MUTED*) title=\"$title (stumm)\" ;;
esac
")))

(define brightness-osd
  (let ((brightnessctl (file-append brightnessctl "/bin/brightnessctl")))
    (osd-script "brightness-osd" brightnessctl
                " -q --class=backlight set \"$1\"
percent=$(" brightnessctl
                " -m --class=backlight | cut -d, -f4 | tr -d %)
title=Helligkeit
")))
