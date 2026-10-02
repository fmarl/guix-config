(define-module (common system security)
  #:use-module (guix gexp)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu services dbus)
  #:use-module (gnu services security-token)
  #:use-module (gnu services sysctl)
  #:use-module (gnu system pam)
  #:use-module (gnu packages security-token)
  #:use-module (common users)
  #:export (%sudoers
            %security-services))

(define u2f-mappings
  (plain-file "u2f-mappings"
              (string-join (map (lambda (user)
                                  (string-append (user-name user) ":"
                                                 (user-u2f-keys user)))
                                (filter user-u2f-keys %users))
                           "\n" 'suffix)))

(define (pam-services-extension names transform)
  "Apply TRANSFORM to the PAM services called NAMES."
  (pam-extension
   (transformer
    (lambda (pam)
      (if (member (pam-service-name pam) names)
          (transform pam)
          pam)))))

(define u2f-pam-extension
  (pam-services-extension
   '("login" "greetd" "sudo")
   (lambda (pam)
     (pam-service
      (inherit pam)
      (auth (cons (pam-entry
                   (control "sufficient")
                   (module (file-append pam-u2f "/lib/security/pam_u2f.so"))
                   (arguments
                    (list "cue" "origin=pam://yubi"
                          #~(string-append "authfile=" #$u2f-mappings))))
                  (pam-service-auth pam)))))))

(define umask-pam-extension
  (pam-services-extension
   '("login" "greetd" "sshd")
   (lambda (pam)
     (pam-service
      (inherit pam)
      (session (cons (pam-entry
                      (control "optional")
                      (module "pam_umask.so")
                      (arguments '("umask=0077")))
                     (pam-service-session pam)))))))

(define %sudoers
  (plain-file "sudoers" "\
root ALL=(ALL) ALL
%wheel ALL=(ALL) ALL
Defaults umask=0022
Defaults umask_override
"))

(define %hardened-sysctl-settings
  '(("kernel.core_uses_pid" . "1")
    ("dev.tty.ldisc_autoload" . "0")
    ("kernel.kptr_restrict" . "2")
    ("kernel.yama.ptrace_scope" . "1")
    ("fs.protected_fifos" . "2")
    ("fs.protected_regular" . "2")
    ("fs.suid_dumpable" . "0")
    ("net.core.bpf_jit_enable" . "0")
    ("net.ipv4.tcp_rfc1337" . "1")
    ("net.ipv4.conf.default.accept_source_route" . "0")
    ("net.ipv4.conf.all.log_martians" . "1")
    ("net.ipv4.conf.all.rp_filter" . "1")
    ("net.ipv4.conf.default.log_martians" . "1")
    ("net.ipv4.conf.default.rp_filter" . "1")
    ("net.ipv4.icmp_echo_ignore_broadcasts" . "1")
    ("net.ipv4.conf.all.accept_redirects" . "0")
    ("net.ipv4.conf.all.secure_redirects" . "0")
    ("net.ipv4.conf.default.accept_redirects" . "0")
    ("net.ipv4.conf.default.secure_redirects" . "0")
    ("net.ipv6.conf.all.accept_redirects" . "0")
    ("net.ipv6.conf.default.accept_redirects" . "0")
    ("net.ipv4.conf.all.send_redirects" . "0")
    ("net.ipv4.conf.default.send_redirects" . "0")))

(define %sysctl-service
  (service sysctl-service-type
           (sysctl-configuration
            (settings (append %hardened-sysctl-settings
                              %default-sysctl-settings)))))

(define pcsc-polkit-rules
  (file-union
   "pcsc-polkit-rules"
   `(("share/polkit-1/rules.d/50-pcsc.rules"
      ,(plain-file
        "50-pcsc.rules"
        "polkit.addRule(function(action, subject) {
  if ((action.id == \"org.debian.pcsc-lite.access_pcsc\" ||
       action.id == \"org.debian.pcsc-lite.access_card\") &&
      subject.isInGroup(\"plugdev\")) {
    return polkit.Result.YES;
  }
});
")))))

(define %security-services
  (list (service pcscd-service-type)
        ;; Without logind no session is active, which pcsc-lite requires
        (simple-service 'pcsc-polkit polkit-service-type
                        (list pcsc-polkit-rules))

        ;; fido2 (Yubikey etc)
        (udev-rules-service 'fido2 libfido2
                            #:groups '("plugdev"))
        (udev-rules-service 'yubikey-personalization yubikey-personalization)
        (udev-rules-service 'u2f-host libu2f-host)

        %sysctl-service

        (simple-service 'pam-extensions pam-root-service-type
                        (list u2f-pam-extension umask-pam-extension))))
