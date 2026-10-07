(define-module (hosts workstation system)
  #:use-module (gnu)
  #:use-module (gnu services linux)
  #:use-module (gnu services ssh)
  #:use-module (nongnu packages linux)
  #:use-module (common users)
  #:use-module (common system base)
  #:use-module (common system desktop)
  #:use-module (common system filesystem)
  #:use-module (common system kernel)
  #:use-module (common system networking)
  #:use-module (hosts workstation hardware)
  #:export (%system))

(define %system
  (operating-system
    (inherit %base-os)
    (host-name "workstation")
    (kernel (linux-with-defconfig (local-file "defconfig")))
    (initrd-modules (list "nvme" "usbhid" "hid-generic"))
    (firmware (list amdgpu-firmware realtek-firmware))

    (services
     (append (desktop-session 'workstation)
             (network-services #:static 'workstation #:open-tcp-ports '("ssh"))
             (list (simple-service 'sensors kernel-module-loader-service-type
                                   (list "it87"))
                   (service openssh-service-type
                     (openssh-configuration
                       (password-authentication? #f)
                       (permit-root-login #f)
                       (challenge-response-authentication? #f)
                       (x11-forwarding? #f)
                       ;; StreamLocalBindUnlink is needed for gpg-agent forwarding
                       (extra-content (string-append
                                       "AllowUsers " (user-name %primary-user) "\n"
                                       "StreamLocalBindUnlink yes\n")))))
             (operating-system-user-services %base-os)))

    (mapped-devices %mapped-devices)
    (file-systems (append %file-systems %hardened-base-file-systems))))

%system
