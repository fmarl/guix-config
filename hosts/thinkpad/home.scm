(define-module (hosts thinkpad home)
  #:use-module (common home base)
  #:use-module (sagittarius packages vpn)
  #:export (%home))

(define %home
  (base-home-environment 'thinkpad
                         #:packages (list mullvad-vpn-desktop)
                         #:services (append (desktop-services #:mobile? #t)
                                            (secrets-services 'thinkpad))))

%home
