(define-module (my desktop)
  #:use-module (guix gexp)
  #:use-module (gnu services)
  #:use-module (gnu services xorg)
  #:use-module (gnu services base)
  #:use-module (gnu services desktop)
  #:use-module (gnu services sound)
  #:use-module (gnu packages suckless))

(define login-manager-service
  (list
   (service elogind-service-type)
   (service gdm-service-type)
   (service x11-socket-directory-service-type)
   gdm-file-system-service))

(define screen-locker-service
  (service screen-locker-service-type
	   (screen-locker-configuration
            (name "slock")
            (program (file-append slock "/bin/slock")))))


(define-public (make-desktop desktop-service)
  (append
   login-manager-service
   (list
    desktop-service
    screen-locker-service
    fontconfig-file-system-service)))
