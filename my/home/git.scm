(define-module (my home git)
  #:use-module (gnu home services)
  #:use-module (gnu home services version-control)
  #:use-module (gnu packages))

(define-public %git-package
  (specifications->packages (list "git")))

(define-public %git-config-service
  (list
   (service home-git-service-type
            (home-git-configuration
             (user-name "Florian Marrero Liestmann")
             (user-email "f.m.liestmann@fx-ttr.de")
             (extra-content
              '((core
                 (editor . "emacsclient"))
                (pull
                 (rebase . "false"))
                (init
                 (defaultBranch . "main"))))))))
