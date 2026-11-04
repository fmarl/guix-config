;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common home secrets)
  #:use-module (guix gexp)
  #:use-module (gnu home services)
  #:use-module (gnu packages password-utils)
  #:use-module (common home helpers)
  #:use-module (common home ssh)
  #:use-module (common machines)
  #:export (secrets-services))

(define secret-script
  (shell-script "secret"
                "cd \"$HOME\" && exec " (file-append sops "/bin/sops")
                " --decrypt --extract \"[\\\"$1\\\"]\""
                " \"$HOME/.config/sops/secrets.yaml\"\n"))

(define (secrets-services machine)
  (list (home-packages sops)
        (simple-service 'secret-files home-files-service-type
                        `((".local/bin/secret" ,secret-script)
                          (".config/sops/secrets.yaml"
                           ,(host-file (machine-name machine)
                                       "secrets.yaml"))))))
