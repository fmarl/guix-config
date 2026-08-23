(define-module (my linux)
  #:use-module (guix gexp)
  #:use-module (nongnu packages linux)
  #:use-module (gnu packages linux)
  #:use-module (guix packages)
  #:export (linux-default))

(define (linux-default config)
  (package
    (inherit (customize-linux #:linux linux
                              #:defconfig config))))
