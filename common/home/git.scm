(define-module (common home git)
  #:use-module (guix gexp)
  #:use-module (gnu packages version-control)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:use-module (common users)
  #:use-module (common home emacs)
  #:use-module (common home helpers)
  #:export (%git-services))

(define git-config
  (ini-file
   "git-config"
   `(("user"
      ("email" . ,(user-email %primary-user))
      ("name" . ,(user-full-name %primary-user))
      ("signingKey" . ,(user-gpg-key %primary-user)))
     ("commit"
      ("gpgSign" . #f))
     ("core"
      ("editor" . ,(string-append "emacsclient -s " %emacs-socket " -t -a ''"))
      ("whitespace" . "fix,-indent-with-non-tab,trailing-space,cr-at-eol")
      ("autocrlf" . #f)
      ("safecrlf" . #t))
     ("log"
      ("abbrevCommit" . #t))
     ("pull"
      ("rebase" . #t))
     ("tag"
      ("gpgSign" . #f))
     ("diff"
      ("renames" . "copies")
      ("algorithm" . "patience")
      ("context" . 3))
     ("format"
      ("subjectprefix" . "PATCH")
      ("signoff" . #t)
      ("numbered" . "auto")
      ("headers" . "Content-Type: text/plain; charset=UTF-8"))
     ("sendemail"
      ("sendmailCmd" . "msmtp -a default")
      ("from" . ,(user-email %primary-user))
      ("chainreplyto" . #f)
      ("confirm" . "always")
      ("annotate" . "yes")
      ("suppresscc" . "self")
      ("to" . "linux-kernel@vger.kernel.org"))
     ("alias"
      ("co" . "checkout")
      ("st" . "status")
      ("ci" . "commit")
      ("br" . "branch")
      ("lg" . "log --graph --oneline --decorate --all"))
     ("color"
      ("ui" . "auto")))))

(define git-ignore
  (plain-file "git-ignore" ".direnv/\n.cache/\n"))

(define %git-services
  (list (home-packages git)
	(simple-service 'git-config
			home-xdg-configuration-files-service-type
			`(("git/config" ,git-config)
			  ("git/ignore" ,git-ignore)))))
