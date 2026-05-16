(define-module (common home shell)
  #:use-module (guix gexp)
  #:use-module (gnu packages admin)
  #:use-module (gnu packages rust-apps)
  #:use-module (gnu packages shellutils)
  #:use-module (gnu packages terminals)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:use-module (gnu home services shells)
  #:use-module (common home helpers)
  #:export (%shell-services))

(define locale-variables
  (simple-service 'locale-variables
		  home-environment-variables-service-type
		  (map (lambda (var)
			 (cons var "de_DE.UTF-8"))
		       '("LC_ADDRESS" "LC_IDENTIFICATION" "LC_MEASUREMENT"
			 "LC_MONETARY" "LC_NAME" "LC_NUMERIC" "LC_PAPER"
			 "LC_TELEPHONE" "LC_TIME"))))

(define %shell-services
  (list (home-packages direnv fzf ripgrep htop zsh-syntax-highlighting)
	(service home-zsh-service-type
		 (home-zsh-configuration
		  (zshrc (list (local-file
				"./../../dotfiles/.zshrc"
				"zshrc")))
		  (zshenv (list (local-file
				 "./../../dotfiles/.zshenv"
				 "zshenv")))))
	locale-variables))
