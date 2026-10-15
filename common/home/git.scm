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
  (ini-file "git-config"
            `(("user" ("email" unquote
                       (user-email %user))
               ("name" unquote
                (user-full-name %user))
               ("signingKey" unquote
                (user-gpg-key %user)))
              ("commit" ("gpgSign" . #t))
              ("core"
               ("whitespace" . "fix,-indent-with-non-tab,trailing-space,cr-at-eol")
               ("autocrlf" . #f)
               ("safecrlf" . #t))
              ("safe" ("bareRepository" . "explicit"))
              ("log" ("abbrevCommit" . #t))
              ("pull" ("rebase" . #t))
              ("tag" ("gpgSign" . #t))
              ("diff" ("renames" . "copies")
               ("algorithm" . "patience")
               ("context" . 3))
              ("alias" ("co" . "checkout")
               ("st" . "status")
               ("ci" . "commit")
               ("br" . "branch")
               ("lg" . "log --graph --oneline --decorate --all"))
              ("color" ("ui" . "auto")))))

(define git-ignore
  (plain-file "git-ignore" ".direnv/\n.cache/\n.env*"))

(define %git-services
  (list (home-packages git)
        (simple-service 'git-config home-xdg-configuration-files-service-type
                        `(("git/config" ,git-config)
                          ("git/ignore" ,git-ignore)))))
