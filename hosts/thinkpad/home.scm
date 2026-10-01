(define-module (hosts thinkpad home)
  #:use-module (common home base)
  #:use-module (sagittarius packages vpn)
  #:export (%home))

(define %home
  (base-home-environment 'thinkpad
                         #:mobile? #t
                         #:packages (list mullvad-vpn-desktop)))

%home
