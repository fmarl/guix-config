(define-module (my home zsh)
  #:use-module (guix gexp)
  #:use-module (gnu services)
  #:use-module (gnu home services shells))


(define-public %zsh-service
  (list(service home-zsh-service-type
		(home-zsh-configuration
		 (zshrc (list (local-file
			       "./../../dotfiles/.zshrc"
			       "zshrc")))
		 (zshenv (list (local-file
				"./../../dotfiles/.zshenv"
				"zshenv"))))
		)))

