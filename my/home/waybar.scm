(define-module (my home waybar)
  #:use-module (guix gexp)
  #:use-module (gnu packages)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:export (
	    %waybar-services
	    %waybar-packages
))

(define %waybar-services
  (list (simple-service 'lf-config
			home-files-service-type
			`((".config/waybar/config"
			   ,(local-file "../../dotfiles/.config/waybar/config"))
			  (".config/waybar/style.css"
			   ,(local-file "../../dotfiles/.config/waybar/style.css")))
			)))

(define %waybar-packages
  (specifications->packages
   (list "waybar")))
