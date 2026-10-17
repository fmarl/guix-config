;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common system test)
  #:use-module (gnu)
  #:use-module (gnu packages linux)
  #:use-module (gnu system vm)
  #:use-module (gnu tests)
  #:use-module (guix gexp)
  #:use-module (common machines)
  #:use-module (common system security)
  #:use-module (srfi srfi-26)
  #:export (host-system-test))

(define %vm-kernel-configs
  '("CONFIG_VIRTIO_MENU=y" "CONFIG_VIRTIO_PCI=y"
    "CONFIG_VIRTIO_BLK=y"
    "CONFIG_VIRTIO_CONSOLE=y"
    "CONFIG_HW_RANDOM_VIRTIO=y"
    "CONFIG_NET_VENDOR_INTEL=y"
    "CONFIG_E1000=y"
    "CONFIG_NET_9P=y"
    "CONFIG_NET_9P_VIRTIO=y"
    "CONFIG_NETWORK_FILESYSTEMS=y"
    "CONFIG_9P_FS=y"
    "CONFIG_EXT4_FS=y"
    "CONFIG_OVERLAY_FS=m"
    "CONFIG_TMPFS_XATTR=y"
    "CONFIG_DRM_CIRRUS_QEMU=m"))

(define (vm-file-system fs)
  ;; A tmpfs on /gnu would hide the store shared with the host
  (if (and (member (file-system-type fs)
                   '("btrfs" "vfat"))
           (not (string=? (file-system-mount-point fs) "/gnu")))
      (file-system
        (inherit fs)
        (device "tmpfs")
        (type "tmpfs")
        (options #f)
        (create-mount-point? #t)
        (check? #f)
        (dependencies (filter file-system?
                              (file-system-dependencies fs)))) fs))

(define (rename-interface interface networking)
  (static-networking (inherit networking)
                     (addresses (map (lambda (address)
                                       (if (equal? (network-address-device
                                                    address) interface)
                                           (network-address (inherit address)
                                                            (device "eth0"))
                                           address))
                                     (static-networking-addresses networking)))))

(define (vm-operating-system machine system)
  (operating-system
    (inherit system)
    (bootloader (bootloader-configuration
                  (bootloader grub-bootloader)
                  (targets '("/dev/vda"))))
    (kernel (customize-linux #:linux (operating-system-kernel system)
                             #:configs %vm-kernel-configs))
    (kernel-arguments (cons "net.ifnames=0"
                            (operating-system-user-kernel-arguments system)))
    (mapped-devices '())
    (file-systems (map vm-file-system
                       (operating-system-file-systems system)))
    (services
     (modify-services (operating-system-user-services system)
       (static-networking-service-type config =>
                                       (map (cut rename-interface
                                                 (machine-interface machine)
                                                 <>) config))))))

(define %marionette-modules
  '((gnu services herd)
    (guix combinators)))

(define %test-modules
  '((gnu build marionette)
    (common build test)))

(define (host-test vm services apparmor-profiles open-tcp-ports)
  (with-imported-modules %test-modules
                         #~(begin
                             (use-modules (common build test)
                                          (gnu build marionette)
                                          (srfi srfi-64))

                             (define marionette
                               (make-marionette (list #$vm)))

                             (test-runner-current (system-test-runner #$output))
                             (test-begin "host")

                             (for-each (lambda (service)
                                         (test-assert (format #f "~a running"
                                                              service)
                                                      (guest-start marionette
                                                                   service)))
                                       '#$(append '(nftables
                                                    persistent-secrets
                                                    term-tty1) services))

                             (test-assert
                              "kernel lockdown in confidentiality mode"
                              (string-contains (guest-file marionette
                                                "/sys/kernel/security/lockdown")
                                               "[confidentiality]"))

                             (test-equal "module signatures enforced" "Y\n"
                                         (guest-file marionette
                                          "/sys/module/module/parameters/sig_enforce"))

                             (test-equal "apparmor profiles enforced"
                                         '#$apparmor-profiles
                                         (let ((profiles (guest-file
                                                          marionette
                                                          "/sys/kernel/security/apparmor/profiles")))
                                           (filter (lambda (name)
                                                     (string-contains profiles
                                                      (string-append name
                                                       " (enforce)")))
                                                   '#$apparmor-profiles)))

                             (test-equal "hardened sysctl settings"
                                         '()
                                         (begin
                                           (guest-start marionette
                                                        'sysctl)
                                           (sysctl-mismatches marionette
                                                              '#$%hardened-sysctl-settings)))

                             (test-assert "/proc hides other users' processes"
                              (begin
                                (guest-start marionette
                                             'proc-hidepid)
                                (mounted-with? marionette "/proc"
                                               "hidepid=invisible")))

                             (test-assert "/dev/shm is noexec"
                                          (mounted-with? marionette "/dev/shm"
                                                         "noexec"))

                             (test-assert "/tmp is nosuid and nodev"
                                          (mounted-with? marionette "/tmp"
                                                         "nosuid" "nodev"))

                             (test-assert "/home is nosuid and nodev"
                                          (mounted-with? marionette "/home"
                                                         "nosuid" "nodev"))

                             (test-assert
                              "/var/log is nosuid, nodev and noexec"
                              (mounted-with? marionette "/var/log" "nosuid"
                                             "nodev" "noexec"))

                             (test-equal "unneeded setuid programs removed"
                                         '()
                                         (filter (lambda (program)
                                                   (guest-file-exists?
                                                    marionette
                                                    (string-append
                                                     "/run/privileged/bin/"
                                                     program)))
                                                 '("su" "passwd" "mount"
                                                   "umount" "ping" "newuidmap")))

                             (test-assert "sudo is privileged"
                                          (guest-file-exists? marionette
                                           "/run/privileged/bin/sudo"))

                             (let ((ruleset (guest-output marionette
                                                          #$(file-append
                                                             nftables
                                                             "/sbin/nft")
                                                          "list" "ruleset")))
                               (test-assert "firewall drops input by default"
                                            (string-contains ruleset
                                             "type filter hook input priority filter; policy drop;"))

                               (test-equal
                                "firewall opens only the expected ports to the LAN"
                                '#$(sort open-tcp-ports <)
                                (lan-tcp-ports ruleset
                                               #$%lan-subnet)))

                             (test-end)
                             (exit (zero? (test-runner-fail-count
                                           (test-runner-current)))))))

(define* (host-system-test name
                           system
                           #:key (services '())
                           (apparmor-profiles '())
                           (open-tcp-ports '()))
  (let* ((host (symbol->string name))
         (os (vm-operating-system (lookup-machine name) system))
         (vm (virtual-machine (operating-system
                                (marionette-operating-system os
                                 #:imported-modules %marionette-modules))
                              (memory-size 2048)
                              (cpu-count 2))))
    (system-test (name host)
                 (description (string-append "Boot " host
                               " in a VM and check its hardening."))
                 (value (gexp->derivation (string-append host "-test")
                                          (host-test vm services
                                                     apparmor-profiles
                                                     open-tcp-ports))))))
