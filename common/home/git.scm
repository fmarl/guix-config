;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

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
      ("gpgSign" . #t))
     ("core"
      ("whitespace" . "fix,-indent-with-non-tab,trailing-space,cr-at-eol")
      ("autocrlf" . #f)
      ("safecrlf" . #t))
     ("log"
      ("abbrevCommit" . #t))
     ("pull"
      ("rebase" . #t))
     ("tag"
      ("gpgSign" . #t))
     ("diff"
      ("renames" . "copies")
      ("algorithm" . "patience")
      ("context" . 3))
     ("format"
      ("subjectprefix" . "PATCH")
      ("signoff" . #t)
      ("numbered" . "auto")
      ("headers" . "Content-Type: text/plain; charset=UTF-8"))
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
	(simple-service 'git-editor
			home-environment-variables-service-type
			`(("GIT_EDITOR" . ,emacs-tty)))
	(simple-service 'git-config
			home-xdg-configuration-files-service-type
			`(("git/config" ,git-config)
			  ("git/ignore" ,git-ignore)))))
