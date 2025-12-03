(define-module (my linux)
  #:use-module (nongnu packages linux)
  #:use-module (gnu packages linux)  
  #:use-module (guix packages)
  #:export (linux-hardened))

(define linux-hardened
  (package
    (inherit (customize-linux
	      #:linux linux
	      #:configs '("CONFIG_SECURITY_LANDLOCK=y"
			  "CONFIG_LSM=\"yama,loadpin,safesetid,integrity,apparmor,smack,landlock\"")))))
