(define-module (my desktop)
  #:use-module (guix gexp)
  #:use-module (gnu services)
  #:use-module (gnu services xorg)
  #:use-module (gnu services base)
  #:use-module (gnu services desktop)
  #:use-module (gnu services sound)
  #:use-module (gnu services lightdm)
  #:use-module (gnu services dbus)
  #:use-module (gnu services shepherd)
  #:use-module (gnu packages suckless)
  #:use-module (gnu system keyboard)
  #:use-module (srfi srfi-1)
  #:use-module (ice-9 match)
  #:use-module (guix build utils)
  #:export (
	    screen-locker-service
	    mate-desktop-services
	    gdm-login-manager-services
	    lightdm-login-manager-services
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

(define mate-desktop-services
  (list
   (service mate-desktop-service-type)))

(define gdm-login-manager-services
  (list
   (service gdm-service-type)
   gdm-file-system-service))

(define lightdm-login-manager-services
  (list
   (service lightdm-service-type
	    (lightdm-configuration
	     (xorg-configuration common-xorg-config)
	     (greeters (list (lightdm-gtk-greeter-configuration)))))))

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
     (default-value #f) ; no default value required
     (description
      "Create the XDG_RUNTIME_DIR."))))

(define* (make-desktop desktop-services #:key (login-manager-services lightdm-login-manager-services))
  (append
   login-manager-services
   desktop-services
   (list
    screen-locker-service
    fontconfig-file-system-service
    (service x11-socket-directory-service-type)
    ;; D-Bus stuff
    (service polkit-service-type)
    (service seatd-service-type)
    (service dbus-root-service-type)
    ;; Create XDG_RUNTIME_DIR
    (service xdg-runtime-dir-service-type))))
