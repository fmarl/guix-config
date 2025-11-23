(define-module (my home base)
  #:use-module (guix gexp)
  #:use-module (gnu packages)
  #:use-module (gnu packages gnupg)
  #:use-module (gnu services)
  #:use-module (gnu home services desktop)
  #:use-module (gnu home services gnupg)
  #:use-module (my home lf)
  #:use-module (my home shell)
  #:use-module (my home emacs)
  #:use-module (my home git)
  #:export (
	    %my-home-packages
	    %my-home-desktop-packages
	    %my-home-services
	    %my-home-desktop-services))

(define %my-base-fonts
  (specifications->packages
   (list "font-hack" "font-awesome-nonfree")))

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

(define %my-home-desktop-packages
  (append
   (specifications->packages
    (list "librewolf"
	  "alacritty"))
   %my-home-packages))


(define %my-home-services
  (append
   (list
    (service home-gpg-agent-service-type
             (home-gpg-agent-configuration
              (pinentry-program
               (file-append pinentry-emacs "/bin/pinentry-emacs")))))

   %shell-services
   %lf-services
   %git-services
   %emacs-services))

(define %my-home-desktop-services
  (append
   (list
    (service home-dbus-service-type))
   %my-home-services))

