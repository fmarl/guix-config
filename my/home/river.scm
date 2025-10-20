(define-module (my home river)
  #:use-module (gnu packages)
  #:use-module (gnu packages river))

(define-public %river-package
  (specifications->packages
   (list "river")))