(use-modules (gnu home)
             (gnu packages)
             (gnu services)
             (guix gexp)
             (gnu home services shells)
	     (gnu home services ssh)
	     (my utils)
	     (my home base)
	     (my home emacs)
	     (my home river)
	     (my home waybar))

(home-environment
 (packages (append
	    %my-home-desktop-packages
	    %emacs-packages
	    %river-packages
	    %waybar-packages
	    ))
 
 (services
  (append
   (list
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
			      (identity-file "~/.ssh/id_ed25519"))
		(openssh-host (name "boson")
			      (host-name "192.168.0.171")
			      (user "marrero")
			      (port 22)
			      (identity-file "~/.ssh/id_ed25519"))))
	      (authorized-keys (map (lambda (file) (local-file file))
				    (relative-host-files "workstation" "/pubkeys")))
	      (add-keys-to-agent "yes")))
    (service home-ssh-agent-service-type
         (home-ssh-agent-configuration
          (extra-options '("-t" "1h30m")))))
   %emacs-services
   %river-services
   %waybar-services
   %my-home-services
   %base-home-services)))
