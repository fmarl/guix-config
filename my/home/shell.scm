(define-module (my home shell)
  #:use-module (guix gexp)
  #:use-module (gnu services)
  #:use-module (gnu packages)
  #:use-module (gnu home services shells))


(define-public %shell-packages
  (specifications->packages
     (list "direnv"
	   "starship"
	   "fzf"
	   "ripgrep")))

(define-public %shell-services
  (list(service home-zsh-service-type
		(home-zsh-configuration
		 (zshrc (list (local-file
			       "./../../dotfiles/.zshrc"
			       "zshrc")))
		 (zshenv (list (local-file
				"./../../dotfiles/.zshenv"
				"zshenv"))))
		)))

