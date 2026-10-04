(define-module (common home ssh)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:use-module (gnu home services ssh)
  #:use-module (srfi srfi-1)
  #:use-module (common machines)
  #:use-module (common users)
  #:export (%ssh-host-names
	    ssh-services))

(define %identity-file "~/.ssh/id_ed25519")

(define %git-hosts '("codeberg.org" "github.com"))

(define %ssh-host-names
  (append %git-hosts
	  (map (compose symbol->string machine-name) %addressed-machines)))

(define* (ssh-host name host-name user #:key (server-alive-count-max 2))
  (openssh-host (name name)
		(host-name host-name)
		(user user)
		(port 22)
		(identity-file %identity-file)
		(extra-content
		 (string-append "  HashKnownHosts yes\n"
				"  ServerAliveInterval 30\n"
				"  ServerAliveCountMax "
				(number->string server-alive-count-max) "\n"))))

(define (git-host host-name)
  (ssh-host host-name host-name "git" #:server-alive-count-max 1))

(define (lan-hosts self)
  "SSH hosts for all machines with a fixed address, except SELF."
  (filter-map (lambda (machine)
		(and (not (eq? (machine-name machine) self))
		     (ssh-host (symbol->string (machine-name machine))
			       (machine-address machine)
			       (user-name %primary-user))))
	      %addressed-machines))

(define drop-in-host
  (openssh-host (match-criteria "all")
		(extra-content "  Include config.d/*\n")))

(define* (ssh-services host-name #:key (authorized-keys #f))
  "Other services can add configuration as files in ~/.ssh/config.d/."
  (list (service home-openssh-service-type
		 (home-openssh-configuration
		  (hosts (cons drop-in-host
			       (append (map git-host %git-hosts)
				       (lan-hosts host-name))))
		  (authorized-keys authorized-keys)
		  (add-keys-to-agent "yes")))
	(service home-ssh-agent-service-type
		 (home-ssh-agent-configuration
		  (extra-options '("-t" "1h30m"))))))
