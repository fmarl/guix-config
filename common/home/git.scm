;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common home git)
  #:use-module (guix gexp)
  #:use-module (gnu home services)
  #:use-module (gnu packages version-control)
  #:use-module (common home helpers)
  #:use-module (common users)
  #:export (%git-services))

(define git-config
  (ini-file
   "git-config"
   `(("user"
      ("email" . ,(user-email %user))
      ("name" . ,(user-full-name %user))
      ("signingKey" . ,(user-gpg-key %user)))
     ("commit"
      ("gpgSign" . #t))
     ("core"
      ("whitespace" . "fix,-indent-with-non-tab,trailing-space,cr-at-eol")
      ("autocrlf" . #f)
      ("safecrlf" . #t))
     ("safe"
      ("bareRepository" . "explicit"))
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
     ("alias"
      ("co" . "checkout")
      ("st" . "status")
      ("ci" . "commit")
      ("br" . "branch")
      ("lg" . "log --graph --oneline --decorate --all")
      ("mirror" . "!f() { \
r=$(git remote get-url origin | sed 's|.*fmarl/||; s|\\.git$||'); \
git config --unset-all remote.origin.pushurl; \
git remote set-url --add --push origin codeberg.org:fmarl/$r && \
git remote set-url --add --push origin git@github.com:fmarl/$r.git; \
}; f"))
     ("color"
      ("ui" . "auto")))))

(define git-ignore
  (plain-file "git-ignore" ".direnv/\n.cache/\n.env*"))

(define %git-services
  (list (home-packages git)
        (simple-service 'git-config home-xdg-configuration-files-service-type
                        `(("git/config" ,git-config)
                          ("git/ignore" ,git-ignore)))))
