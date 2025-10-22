(define-module (my home common)
  #:use-module (gnu packages)
  #:use-module (my home lf)
  #:use-module (my home shell))

(define-public %common-packages
  (append
   (specifications->packages
    (list "git"))
   %shell-packages
   %lf-packages))

(define-public %common-services
  (append
   %shell-services
   %lf-services))

(define-public %common-desktop-packages
  (append
   (specifications->packages
    (list "librewolf"
	  "alacritty"))
   %common-packages))
