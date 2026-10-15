;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common home base)
  #:use-module (guix gexp)
  #:use-module (gnu home)
  #:use-module (gnu home services)
  #:use-module (gnu home services sound)
  #:use-module (gnu home services xdg)
  #:use-module (gnu packages fonts)
  #:use-module (gnu packages gnome)
  #:use-module (gnu packages librewolf)
  #:use-module (gnu packages pdf)
  #:use-module (gnu packages ssh)
  #:use-module (gnu packages text-editors)
  #:use-module (gnu services)
  #:use-module (nongnu packages messaging)
  #:use-module (sagittarius locked image-viewers)
  #:use-module (sagittarius locked pdf)
  #:use-module (sagittarius locked video)
  #:use-module (common home alacritty)
  #:use-module (common home bemenu)
  #:use-module (common home dbus)
  #:use-module (common home emacs)
  #:use-module (common home git)
  #:use-module (common home gnupg)
  #:use-module (common home helpers)
  #:use-module (common home mail)
  #:use-module (common home mako)
  #:use-module (common home secrets)
  #:use-module (common home shell)
  #:use-module (common home ssh)
  #:use-module (common home swayidle)
  #:use-module (common home syncthing)
  #:use-module (common home theme)
  #:use-module (common home waybar)
  #:use-module (common home wm)
  #:use-module (common machines)
  #:export (base-home-environment desktop-services)
  #:re-export (secrets-services syncthing-services))

(define (base-services machine)
  (append (list (home-packages openssh font-aporetic)
                (simple-service 'guile-config home-files-service-type
                                `((".guile" ,(local-file
                                              "../../dotfiles/.guile" "guile"))))
                (simple-service 'guix-channels
                                home-xdg-configuration-files-service-type
                                `(("guix/channels.scm" ,(local-file
                                                         "../../dotfiles/.config/guix/channels.scm"))
                                  ("guix/trusted-channels.scm" ,(local-file
                                                                 "../../dotfiles/.config/guix/channels.scm"
                                                                 "trusted-channels.scm"))))
                (service home-xdg-user-directories-service-type
                         (home-xdg-user-directories-configuration (projects
                                                                   "$HOME/Src"))))
          %shell-services %git-services
          (if (machine-wm machine)
              (append (gpg-services machine) %emacs-services)
              server-editor-services)))

(define server-editor-services
  (list (home-packages mg)
        (simple-service 'mg-editor home-environment-variables-service-type
                        `(("EDITOR" unquote
                           (file-append mg "/bin/mg"))))))

(define battery-alert
  (shell-script "battery-alert"
   "notified=\"$XDG_RUNTIME_DIR/battery-alert\"
mkdir -p \"$notified\"
while [ -S \"$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY\" ]; do
    for battery in /sys/class/power_supply/BAT*; do
        marker=\"$notified/${battery##*/}\"
        capacity=$(cat \"$battery/capacity\")
        if [ \"$(cat \"$battery/status\")\" = Discharging ] &&
           [ \"$capacity\" -le 15 ]; then
            [ -e \"$marker\" ] ||
                " libnotify
   "/bin/notify-send -u critical \"Akku fast leer\" \"Noch $capacity %\"
            touch \"$marker\"
        else
            rm -f \"$marker\"
        fi
    done
    sleep 60
done
"))

(define (desktop-services machine)
  (append (list (home-packages librewolf
                               signal-desktop
                               imv-locked
                               zathura-locked
                               zathura-pdf-mupdf
                               mpv-locked)
                (wm-extensions machine
                               'desktop-apps
                               (wm-window-rule "librewolf$"
                                               #:title "^Picture-in-Picture$"
                                               #:floating? #t)
                               (wm-window-rule "(?i)signal"
                                               #:hide-from-screencast? #t))
                (simple-service 'wayland-environment
                                home-environment-variables-service-type
                                '(("_JAVA_AWT_WM_NONREPARENTING" . "1")
                                  ("ELECTRON_OZONE_PLATFORM_HINT" . "auto"))))
          (if (machine-audio? machine)
              (list (service home-pipewire-service-type))
              '())
          (alacritty-services machine)
          (bemenu-services machine)
          %dbus-services
          (emacs-desktop-services machine)
          (theme-services machine)
          (wm-services machine)
          (waybar-services machine)
          (mako-services machine)
          %mail-services
          (swayidle-services machine)
          (if (machine-mobile? machine)
              (list (wm-extensions machine
                                   'battery-alert
                                   (wm-autostart battery-alert)))
              '())))

(define* (base-home-environment machine
                                #:key ssh-clients
                                (packages '())
                                (services '()))
  "Return the home environment of MACHINE with SERVICES added to the base
services."
  (home-environment
    (packages packages)
    (services
     (append services
             (ssh-services (machine-name machine)
                           #:ssh-clients ssh-clients)
             (base-services machine) %base-home-services))))
