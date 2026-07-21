(define-module (my home base)
  #:use-module (guix gexp)
  #:use-module (gnu packages)
  #:use-module (gnu services)
  #:use-module (gnu home services desktop)
  #:use-module (gnu home services sound)
  #:use-module (gnu home services)
  #:use-module (my home lf)
  #:use-module (my home shell)
  #:use-module (my home emacs)
  #:use-module (my home git)
  #:use-module (my home gnupg)
  #:export (
	    %my-home-packages
	    %my-home-desktop-packages
	    %my-home-services
	    %my-home-desktop-services))

(define %my-base-fonts
  (specifications->packages
   (list "font-hack" "font-awesome-nonfree" "font-aporetic")))

(define %my-home-packages
  (append
   (specifications->packages
    (list "git"
	  "openssh"
	  "gnupg"))
   %my-base-fonts
   %shell-packages
   %lf-packages
   %git-packages
   %emacs-packages))

(define %my-home-desktop-themes
  (specifications->packages
   (list
    "adwaita-icon-theme")))

(define %my-home-desktop-packages
  (append
   (specifications->packages
    (list
     "librewolf"
     "alacritty"
     "signal-desktop"))
   %my-home-desktop-themes
   %my-home-packages))


(define %my-home-services
  (append
   %gpg-services
   %shell-services
   %lf-services
   %git-services
   %emacs-services))

(define %my-home-desktop-services
  (append
   (list
    (service home-dbus-service-type)
    (service home-pipewire-service-type)
    (simple-service 'alacritty-config
		    home-files-service-type
		    `((".config/alacritty/alacritty.toml"
		       ,(local-file "../../dotfiles/.config/alacritty/alacritty.toml"))
		      (".config/alacritty/ef_owl.toml"
		       ,(local-file "../../dotfiles/.config/alacritty/ef_owl.toml")))))
   %my-home-services))

