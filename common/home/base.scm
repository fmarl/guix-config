;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common home base)
  #:use-module (guix gexp)
  #:use-module (gnu home)
  #:use-module (gnu packages fonts)
  #:use-module (gnu packages librewolf)
  #:use-module (gnu packages ssh)
  #:use-module (nongnu packages messaging)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:use-module (gnu home services desktop)
  #:use-module (gnu home services sound)
  #:use-module (gnu home services xdg)
  #:use-module (common home alacritty)
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
  #:use-module (common home theme)
  #:use-module (common home waybar)
  #:use-module (common home wm)
  #:use-module (common machines)
  #:export (base-home-environment
	    desktop-services)
  #:re-export (%mail-services
	       secrets-services))

(define base-services
  (append
   (list (home-packages openssh font-aporetic)
	 (simple-service 'guile-config
			 home-files-service-type
			 `((".guile" ,(local-file "../../dotfiles/.guile" "guile"))))
	 (simple-service 'guix-channels
			 home-xdg-configuration-files-service-type
			 `(("guix/channels.scm"
			    ,(local-file "../../dotfiles/.config/guix/channels.scm"))
			   ("guix/trusted-channels.scm"
			    ,(local-file "../../dotfiles/.config/guix/channels.scm"
					 "trusted-channels.scm"))))
	 (service home-xdg-user-directories-service-type))
   %gpg-services
   %shell-services
   %git-services
   %emacs-services))

(define* (desktop-services host-name #:key mobile? (audio? #t))
  (define wm (machine-wm (lookup-machine host-name)))

  (append
   (list (home-packages librewolf signal-desktop)
	 (service home-dbus-service-type)
	 (simple-service 'wayland-environment
			 home-environment-variables-service-type
			 '(("_JAVA_AWT_WM_NONREPARENTING" . "1")
			   ("ELECTRON_OZONE_PLATFORM_HINT" . "auto"))))
   (if audio?
       (list (service home-pipewire-service-type))
       '())
   %alacritty-services
   %theme-services
   (wm-services wm #:audio? audio?)
   (waybar-services wm #:mobile? mobile? #:audio? audio?)
   (mako-services wm)
   (swayidle-services wm)))

(define* (base-home-environment host-name #:key
				(authorized-keys #f)
				(packages '())
				(services '()))
  "Return the home environment of HOST-NAME (a symbol, left out of the SSH
hosts) with SERVICES, e.g. desktop-services, %mail-services or
secrets-services, added to the base services."
  (home-environment
   (packages packages)
   (services (append services
		     (ssh-services host-name
				   #:authorized-keys authorized-keys)
		     base-services
		     %base-home-services))))
