;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common home secrets)
  #:use-module (guix gexp)
  #:use-module (gnu home services)
  #:use-module (gnu packages password-utils)
  #:use-module (gnu packages ssh)
  #:use-module (common home bemenu)
  #:use-module (common home helpers)
  #:use-module (common home ssh)
  #:use-module (common machines)
  #:export (secrets-services))

(define secret-script
  (shell-script "secret" "exec "
                (file-append sops "/bin/sops")
                " --decrypt --extract \"[\\\"$1\\\"]\""
                " \"$HOME/.config/sops/secrets.yaml\"\n"))

(define (ssh-load-key-script theme)
  (let ((ssh-add (file-append openssh "/bin/ssh-add"))
        (ssh-keygen (file-append openssh "/bin/ssh-keygen")))
    (shell-script "ssh-load-key"
                  "fingerprint=$("
                  ssh-keygen
                  " -l -f \"$HOME/"
                  %ssh-public-key-file
                  "\" | cut -d' ' -f2)\n"
                  ssh-add
                  " -l 2>/dev/null | grep -qF \"$fingerprint\" && exit 0
"
                  secret-script
                  " ssh | SSH_ASKPASS="
                  (bemenu-askpass theme)
                  " SSH_ASKPASS_REQUIRE=force "
                  ssh-add
                  " -q -\n")))

(define ssh-load-key-config
  (plain-file "ssh-load-key"
              (string-append "Match originalhost "
                             (string-join %ssh-host-names ",")
                             " exec ~/.local/bin/ssh-load-key\n"
                             "Host "
                             (string-join %ssh-host-names " ")
                             "\n  IdentityFile ~/"
                             %ssh-public-key-file
                             "\n")))

(define (secrets-services machine)
  "Deploy the SOPS secrets and SSH public key of MACHINE."
  (define (own-file name)
    (host-file (machine-name machine) name))

  (list (home-packages sops)
        (simple-service 'secret-files home-files-service-type
                        `((".local/bin/secret" ,secret-script)
                          (".local/bin/ssh-load-key" ,(ssh-load-key-script (machine-theme
                                                                            machine)))
                          (".ssh/config.d/ssh-load-key" ,ssh-load-key-config)
                          (".config/sops/secrets.yaml" ,(own-file
                                                         "secrets.yaml"))
                          (,%ssh-public-key-file ,(own-file "ssh.pub"))))))
