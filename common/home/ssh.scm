(define-module (common home ssh)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:use-module (gnu home services ssh)
  #:use-module (srfi srfi-1)
  #:use-module (ice-9 match)
  #:use-module (common machines)
  #:use-module (common users)
  #:export (ssh-services))

(define %identity-file "~/.ssh/id_ed25519")

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
  (filter-map (match-lambda
		((name . properties)
		 (let ((address (assq-ref properties 'address)))
		   (and address
			(not (eq? name self))
			(ssh-host (symbol->string name) address
				  (user-name %primary-user))))))
	      %machines))

(define* (ssh-services host-name #:key (authorized-keys #f))
  (list (service home-openssh-service-type
		 (home-openssh-configuration
		  (hosts (append (list (git-host "codeberg.org")
				       (git-host "github.com"))
				 (lan-hosts host-name)))
		  (authorized-keys authorized-keys)
		  (add-keys-to-agent "yes")))
	(service home-ssh-agent-service-type
		 (home-ssh-agent-configuration
		  (extra-options '("-t" "1h30m"))))))
