(define-module (my home envs)
  #:use-module (gnu packages lisp)
  #:export (lisp-env))

(define lisp-env
  (list
   sbcl))
