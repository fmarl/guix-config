(define-module (my desktop)
  #:use-module (guix gexp)
  #:use-module (guix records)
  #:use-module (gnu services)
  #:use-module (gnu services xorg)
  #:use-module (gnu services base)
  #:use-module (gnu services desktop)
  #:use-module (gnu services sound)
  #:use-module (gnu services lightdm)
  #:use-module (gnu services dbus)
  #:use-module (gnu services shepherd)
  #:use-module (gnu packages zig-xyz)
  #:use-module (gnu packages suckless)
  #:use-module (gnu packages security-token)
  #:use-module (gnu packages admin)
  #:use-module (gnu packages shells)
  #:use-module (gnu system keyboard)
  #:use-module (srfi srfi-1)
  #:use-module (ice-9 match)
  #:use-module (guix build utils)
  #:export (
	    screen-locker-service
	    mate-desktop-services
	    river-desktop-services
	    gdm-login-manager-services
	    lightdm-login-manager-services
	    greetd+tuigreet-login-manager-services
	    make-desktop
	    ))

(define keyboard-layout
  (keyboard-layout "us" "altgr-intl"))

(define common-xorg-config
  (xorg-configuration
   (keyboard-layout keyboard-layout)))

(define screen-locker-service
  (service screen-locker-service-type
	   (screen-locker-configuration
            (name "slock")
            (program (file-append slock "/bin/slock")))))

;; GDM

(define gdm-login-manager-services
  (list
   (service gdm-service-type)
   gdm-file-system-service))

;; Lightdm

(define lightdm-login-manager-services
  (list
   (service lightdm-service-type
	    (lightdm-configuration
	     (xorg-configuration common-xorg-config)
	     (greeters (list (lightdm-gtk-greeter-configuration)))))))

;; Greetd

(define greetd+tuigreet-login-manager-services
  (list
   (service greetd-service-type
            (greetd-configuration
             (terminals
              (list
	       (greetd-terminal-configuration
		(terminal-vt "1")
		(default-session-command (file-append tuigreet "/bin/tuigreet")))
	       (greetd-terminal-configuration
                (terminal-vt "2")
                (default-session-command
                  (greetd-agreety-session (command
					   (greetd-user-session)))))
	       (greetd-terminal-configuration
                (terminal-vt "3")
                (default-session-command
                  (greetd-agreety-session (command
					   (greetd-user-session)))))
	       (greetd-terminal-configuration
                (terminal-vt "4")
                (default-session-command
                  (greetd-agreety-session (command
					   (greetd-user-session)))))))))))

;; River

(define-record-type* <river-desktop-configuration> river-desktop-configuration
  make-river-desktop-configuration
  river-desktop-configuration?
  (river-package river-package (default river)))

(define river-desktop-service-type
  (service-type
    (name 'river-desktop)
    (description "The river window manager")
    (extensions
     (list (service-extension profile-service-type
			      (compose list river-package))))
    (default-value (river-desktop-configuration))))

(define river-desktop-services
  (list
   (service river-desktop-service-type)))

;; Mate

(define mate-desktop-services
  (list
   (service mate-desktop-service-type)))

;; Other

(define xdg-runtime-dir-service-type
  (let ((xdg-runtime-dir-shepherd-service
         (shepherd-service
          (documentation "Create the XDG_RUNTIME_DIR.")
          (requirement '(file-systems))
          (provision '(xdg-runtime-dir))
          (one-shot? #t)
          (start #~(lambda _
                     (let ((user (getpw "marrero"))
			   (directory "/run/user/1000"))
                       (mkdir-p directory)
		       (chown directory (passwd:uid user) (passwd:gid user))
                       (chmod directory #o700)))))))
    (service-type
     (name 'xdg-runtime-dir-service)
     (extensions
      (list
       (service-extension shepherd-root-service-type
                          (compose
                           list
                           (const xdg-runtime-dir-shepherd-service)))))
     (default-value #f)			; no default value required
     (description
      "Create the XDG_RUNTIME_DIR."))))

(define fido2-services
  (udev-rules-service 'fido2 libfido2 #:groups '("plugdev")))

(define (flatten lst)
  (cond
    ((null? lst) '())
    ((list? (car lst)) (append (flatten (car lst)) (flatten (cdr lst))))
    (else (cons (car lst) (flatten (cdr lst))))))

(define* (make-desktop desktop-services #:key (login-manager-services greetd+tuigreet-login-manager-services))
  (append
   login-manager-services
   (flatten desktop-services)
   (list
    screen-locker-service
    fontconfig-file-system-service
    (service x11-socket-directory-service-type)
    ;; D-Bus stuff
    (service seatd-service-type)
    (service dbus-root-service-type)
    ;; Create XDG_RUNTIME_DIR
    (service xdg-runtime-dir-service-type)
    ;; fido2 (Yubikey etc)
    fido2-services
    )))
