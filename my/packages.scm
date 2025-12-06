(define-module (my packages)
  #:use-module (guix utils)
  #:use-module (guix gexp)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix licenses)
  #:use-module (guix packages)
  #:use-module (guix build-system emacs)
  #:use-module (guix build-system dune)
  #:use-module (gnu packages)
  #:use-module (gnu packages wm)
  #:use-module (gnu packages ocaml)
  #:use-module (gnu packages emacs)
  #:export (my-niri
	    my-ocaml-utop))

(define my-niri
  (package
    (inherit niri)
    (arguments
     (ensure-keyword-arguments (package-arguments niri)
                               '(#:cargo-install-paths '("."))))))

(define my-ocaml-utop
  (package
    (inherit ocaml-utop)
    (propagated-inputs
     (list ocaml-lambda-term
           ocaml-logs
           ocaml-lwt
           ocaml-lwt-react
           ocaml-react
           ocaml-zed))))
