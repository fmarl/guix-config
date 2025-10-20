(define-module (my home common)
  #:use-module (gnu packages)
  #:use-module (my home lf)
  #:use-module (my home zsh))

(define-public %common-packages
  (append
   (specifications->packages
    (list "direnv" "git"))
   %lf-package))

(define-public %common-services
  (append
   %zsh-service
   %lf-config-service))

(define-public %common-desktop-packages
  (append
   (specifications->packages
    (list "librewolf"
	  "alacritty"
	  "fzf"
	  "ripgrep"))
   %common-packages))
