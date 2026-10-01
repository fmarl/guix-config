(define-module (common system kernel)
  #:use-module (guix gexp)
  #:use-module (nongnu packages linux)
  #:use-module (gnu packages linux)
  #:use-module (guix packages)
  #:export (linux-with-defconfig
            %hardened-kernel-arguments))

(define (linux-with-defconfig config)
  (package
    (inherit (customize-linux #:linux linux
                              #:defconfig config))))

(define %hardened-kernel-arguments
  '("slab_nomerge"
    "init_on_free=1"
    "page_alloc.shuffle=1"
    "debugfs=off"))
