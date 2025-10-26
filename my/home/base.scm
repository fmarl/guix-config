(define-module (my home base)
  #:use-module (gnu packages)
  #:use-module (my home lf)
  #:use-module (my home shell)
  #:export (
	    %my-home-packages
	    %my-home-services
	    %my-home-desktop-packages))

(define %my-base-fonts
   (specifications->packages
    (list "font-hack")))

(define %my-home-packages
  (append
   (specifications->packages
    (list "git"))
   %my-base-fonts
   %shell-packages
   %lf-packages))

(define %my-home-services
  (append
   %shell-services
   %lf-services))

(define %my-home-desktop-packages
  (append
   (specifications->packages
    (list "librewolf"
	  "alacritty"))
   %my-home-packages))
