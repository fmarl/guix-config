(define-module (my packages)
  #:use-module (guix utils)
  #:use-module (guix packages)
  #:use-module (gnu packages wm)
  #:export (my-niri))

(define my-niri
  (package
    (inherit niri)
    (arguments
     (ensure-keyword-arguments (package-arguments niri)
                               '(#:cargo-install-paths '("."))))))
