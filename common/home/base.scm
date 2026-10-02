(define-module (common home base)
  #:use-module (guix gexp)
  #:use-module (gnu home)
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
  #:use-module (common home lf)
  #:use-module (common home mail)
  #:use-module (common home mako)
  #:use-module (common home niri)
  #:use-module (common home shell)
  #:use-module (common home ssh)
  #:use-module (common home swayidle)
  #:use-module (common home theme)
  #:use-module (common home waybar)
  #:export (base-home-environment))

(define base-services
  (append
   (list (home-packages "openssh" "font-hack" "font-aporetic")
	 (simple-service 'guile-config
			 home-files-service-type
			 `((".guile" ,(local-file "../../dotfiles/.guile" "guile"))))
	 (simple-service 'guix-channels
			 home-xdg-configuration-files-service-type
			 `(("guix/channels.scm"
			    ,(local-file "../../dotfiles/.config/guix/channels.scm"))))
	 (service home-xdg-user-directories-service-type
		  (home-xdg-user-directories-configuration
		   (download "$HOME/downloads"))))
   %gpg-services
   %shell-services
   %git-services
   %emacs-services
   %lf-services))

(define* (desktop-services #:key mobile?)
  (append
   (list (home-packages "librewolf" "signal-desktop")
	 (service home-dbus-service-type)
	 (service home-pipewire-service-type)
	 (simple-service 'java-wayland
			 home-environment-variables-service-type
			 '(("_JAVA_AWT_WM_NONREPARENTING" . "1"))))
   %alacritty-services
   %theme-services
   %niri-services
   (waybar-services #:mobile? mobile?)
   %mako-services
   %swayidle-services))

(define* (base-home-environment host-name #:key
				(desktop? #t)
				mobile?
				mail?
				(authorized-keys #f)
				(packages '())
				(services '()))
  "Return the home environment of HOST-NAME (a symbol, left out of the SSH hosts).
MOBILE? selects the laptop variant of the desktop, MAIL? adds isync/msmtp."
  (home-environment
   (packages packages)
   (services (append services
		     (ssh-services host-name
				   #:authorized-keys authorized-keys)
		     base-services
		     (if desktop? (desktop-services #:mobile? mobile?) '())
		     (if mail? %mail-services '())
		     %base-home-services))))
