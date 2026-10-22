;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common system security)
  #:use-module (guix gexp)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages security-token)
  #:use-module (gnu services)
  #:use-module (gnu services base)
  #:use-module (gnu services dbus)
  #:use-module (gnu services security-token)
  #:use-module (gnu services shepherd)
  #:use-module (gnu services sysctl)
  #:use-module (gnu system)
  #:use-module (gnu system pam)
  #:use-module (gnu system privilege)
  #:use-module (guix-apparmor services)
  #:use-module (common users)
  #:use-module (srfi srfi-1)
  #:export (%sudoers
            %privileged-programs
            %hardened-sysctl-settings
            %hardening-services
            %security-token-services))

(define u2f-mappings
  (plain-file "u2f-mappings"
              (string-append (user-name %user) ":" (user-u2f-keys %user)
                             "\n")))

(define u2f-authfile
  #~(string-append "authfile=" #$u2f-mappings))

(define (pam-services-extension names transform)
  (pam-extension
   (transformer (lambda (pam)
                  (if (member (pam-service-name pam) names)
                      (transform pam)
                      pam)))))

(define (pam-session-extension names entry)
  (pam-services-extension names
                          (lambda (pam)
                            (pam-service
                             (inherit pam)
                             (session (cons entry
                                            (pam-service-session pam)))))))

(define u2f-pam-extension
  (pam-services-extension
   '("login" "greetd" "sudo")
   (lambda (pam)
     (pam-service
      (inherit pam)
      (auth (cons (pam-entry
                   (control "sufficient")
                   (module (file-append pam-u2f "/lib/security/pam_u2f.so"))
                   (arguments (list "cue" "origin=pam://yubi" u2f-authfile)))
                  (pam-service-auth pam)))))))

(define umask-pam-extension
  (pam-session-extension '("login" "greetd" "sshd")
                         (pam-entry
                          (control "optional")
                          (module "pam_umask.so")
                          (arguments (list "umask=0077")))))

(define %sudoers
  (plain-file "sudoers" "\
root ALL=(ALL) ALL
%wheel ALL=(ALL) ALL
Defaults umask=0022
Defaults umask_override
"))

(define %unneeded-privileged-programs
  '("/bin/chfn"
    "/bin/sg"
    "/bin/su"
    "/bin/newgrp"
    "/bin/passwd"
    "/bin/mount"
    "/bin/umount"
    "/bin/fusermount"
    "/bin/fusermount3"
    "/bin/ping"
    "/bin/ping6"
    "/bin/newuidmap"
    "/bin/newgidmap"))

(define %privileged-programs
  (remove (lambda (program)
            (let ((file (privileged-program-program program)))
              (and (file-append? file)
                   (member (string-concatenate (file-append-suffix file))
                           %unneeded-privileged-programs))))
          %default-privileged-programs))

(define %hardened-sysctl-settings
  '(("dev.tty.ldisc_autoload" . "0")
    ("kernel.kptr_restrict" . "2")
    ("kernel.yama.ptrace_scope" . "2")
    ("fs.protected_fifos" . "2")
    ("fs.protected_regular" . "2")
    ("fs.suid_dumpable" . "0")
    ("vm.mmap_rnd_bits" . "32")
    ("vm.memfd_noexec" . "2")
    ("-kernel.unprivileged_userns_apparmor_policy" . "0")
    ("net.core.bpf_jit_harden" . "2")
    ("net.ipv4.ping_group_range" . "0 2147483647")
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

(define sysctl-service
  (service sysctl-service-type
           (sysctl-configuration
            (settings (append %hardened-sysctl-settings
                              %default-sysctl-settings)))))

(define pcsc-polkit-rules
  (file-union "pcsc-polkit-rules"
              `(("share/polkit-1/rules.d/50-pcsc.rules"
                 ,(plain-file "50-pcsc.rules" "\
polkit.addRule(function(action, subject) {
  if ((action.id == \"org.debian.pcsc-lite.access_pcsc\" ||
       action.id == \"org.debian.pcsc-lite.access_card\") &&
      subject.isInGroup(\"plugdev\")) {
    return polkit.Result.YES;
  }
});
")))))

(define proc-hidepid-shepherd-service
  (shepherd-service
    (provision '(proc-hidepid))
    (requirement '(file-systems))
    (one-shot? #t)
    (start
     #~(lambda _
         (let* ((polkitd (false-if-exception (getgrnam "polkitd")))
                (options (if polkitd
                             (format #f "remount,hidepid=invisible,gid=~a"
                                     (group:gid polkitd))
                             "remount,hidepid=invisible")))
           (unless (zero? (system* #$(file-append util-linux "/bin/mount")
                                   "-o" options "/proc"))
             (format (current-error-port)
                     "proc-hidepid: cannot remount /proc~%"))
           #t)))
    (documentation "Hide other users' processes in /proc")))

(define %hardening-services
  (list sysctl-service

        (service apparmor-service-type)

        (simple-service 'proc-hidepid shepherd-root-service-type
                        (list proc-hidepid-shepherd-service))
        (simple-service 'proc-hidepid-before-login user-processes-service-type
                        '(proc-hidepid))

        (simple-service 'pam-umask pam-root-service-type
                        (list umask-pam-extension))))

(define %security-token-services
  (list (service pcscd-service-type)
        (simple-service 'pcsc-polkit polkit-service-type
                        (list pcsc-polkit-rules))
        (udev-rules-service 'fido2 libfido2 #:groups '("plugdev"))
        (udev-rules-service 'yubikey-personalization yubikey-personalization)

        (simple-service 'pam-u2f pam-root-service-type
                        (list u2f-pam-extension))))
