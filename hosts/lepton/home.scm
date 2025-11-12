(use-modules
 (guix gexp)
 (gnu home)
 (gnu packages)
 (gnu services)
 (gnu home services)
 (gnu home services shells)
 (gnu home services ssh)
 (my utils)
 (my home base)
 (my home river)
 (my home waybar))

(home-environment
 (packages (append
	    %river-packages
	    %waybar-packages
	    %my-home-desktop-packages))
 
 (services
  (append
   (list
    (simple-service 'env-vars-service
		    home-environment-variables-service-type
		    `(("SSH_AUTH_SOCK" . "$XDG_RUNTIME_DIR/ssh-agent/socket")
                      ("GPG_TTY" . "$(tty)")
                      ("_JAVA_AWT_WM_NONREPARENTING" . #t)))
    
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
	      (add-keys-to-agent "yes")))
    
    (service home-ssh-agent-service-type
             (home-ssh-agent-configuration
              (extra-options '("-t" "1h30m")))))
   %river-services
   %waybar-services
   %my-home-desktop-services
   %base-home-services)))
