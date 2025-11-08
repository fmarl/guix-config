(define-module (my home git)
  #:use-module (guix gexp)
  #:use-module (gnu packages)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:export (
	    %git-services
	    %git-packages))

(define %git-services
  (list (simple-service 'git-config
			home-files-service-type
			`((".config/git/config"
			   ,(local-file "../../dotfiles/.config/git/config"))
			  (".config/git/ignore"
			   ,(local-file "../../dotfiles/.config/git/ignore")))
			)))

(define-public %git-packages
  (specifications->packages
   (list "git")))
