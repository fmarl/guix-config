(define-module (my home base)
  #:use-module (gnu packages)
  #:use-module (gnu packages fonts)
  #:use-module (my home lf)
  #:use-module (my home shell)
  #:export (
	    %my-home-packages
	    %my-home-services
	    %my-home-desktop-packages))

(define %my-home-packages
  (append
   (specifications->packages
    (list "git"))
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
