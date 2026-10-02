(define-module (common home secrets)
  #:use-module (guix gexp)
  #:use-module (gnu packages)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:use-module (common home bemenu)
  #:use-module (common home helpers)
  #:use-module (common home ssh)
  #:export (secrets-services))

(define sops (specification->package "sops"))
(define openssh (specification->package "openssh"))

(define secret-script
  (shell-script "secret"
                "exec " (file-append sops "/bin/sops")
                " --decrypt --extract \"[\\\"$1\\\"]\""
                " \"$HOME/.config/sops/secrets.yaml\"\n"))

(define ssh-load-key-script
  (let ((ssh-add (file-append openssh "/bin/ssh-add"))
        (ssh-keygen (file-append openssh "/bin/ssh-keygen")))
    (shell-script "ssh-load-key"
                  "fingerprint=$(" ssh-keygen
                  " -l -f \"$HOME/.ssh/id_ed25519.pub\" | cut -d' ' -f2)\n"
                  ssh-add " -l 2>/dev/null | grep -qF \"$fingerprint\" && exit 0\n"
                  secret-script " ssh | SSH_ASKPASS=" bemenu-askpass
                  " SSH_ASKPASS_REQUIRE=force " ssh-add " -q -\n")))

(define ssh-load-key-config
  (plain-file "ssh-load-key"
              (string-append "Match originalhost "
                             (string-join (ssh-host-names) ",")
                             " exec ~/.local/bin/ssh-load-key\n"
                             "  IdentityFile ~/.ssh/id_ed25519.pub\n")))

(define (secrets-services host-name)
  "Deploy the SOPS secrets and SSH public key of HOST-NAME.  Secrets are
decrypted on demand with the YubiKey by ~/.local/bin/secret NAME, the SSH key
on the first connection to one of the configured hosts."
  (let ((host (string-append "../../hosts/" (symbol->string host-name))))
    (list (home-packages "sops")
          (simple-service 'secret-files
                          home-files-service-type
                          `((".local/bin/secret" ,secret-script)
                            (".local/bin/ssh-load-key" ,ssh-load-key-script)
                            (".ssh/config.d/ssh-load-key" ,ssh-load-key-config)
                            (".config/sops/secrets.yaml"
                             ,(local-file (assume-source-relative-file-name
                                           (string-append host "/secrets.yaml"))
                                          "secrets.yaml"))
                            (".ssh/id_ed25519.pub"
                             ,(local-file (assume-source-relative-file-name
                                           (string-append host "/ssh.pub"))
                                          "id_ed25519.pub")))))))
