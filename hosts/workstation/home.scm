(use-modules (gnu home)
             (gnu packages)
             (gnu services)
             (guix gexp)
             (gnu home services shells)
	     (gnu home services ssh)
	     (my home emacs)
	     (my home zsh)
	     (my home lf)
	     (my home common))

(home-environment
 (packages (append
	    %common-desktop-packages
	    %emacs-packages
	    ))
 
 (services
  (append (list
	   (service home-openssh-service-type
		    (home-openssh-configuration
		     (hosts
		      (list
		       (openssh-host (name "codeberg")
				     (host-name "codeberg.org")
				     (user "git")
				     (port 22)
				     (identity-file "~/.ssh/id_ed25519"))
		       (openssh-host (name "github")
				     (host-name "github.com")
				     (user "git")
				     (port 22)

				     (identity-file "~/.ssh/id_ed25519")))))))
	  %emacs-services
	  %common-services
          %base-home-services)))
