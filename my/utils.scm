(define-module (my utils)
  #:use-module (ice-9 ftw)
  #:export (
	    base-path
	    relative-path
	    relative-host-path
	    relative-files
	    relative-host-files
	    load-by-hostname))

(define (flatten lst)
  (cond
    ((null? lst) '())
    ((list? (car lst)) (append (flatten (car lst)) (flatten (cdr lst))))
    (else (cons (car lst) (flatten (cdr lst))))))

(define (stat:type=? st type)
  (eq? (stat:type st) type))

(define (base-path)
  (getcwd))

(define (relative-path rpath)
  (string-append (base-path) rpath))
  
(define (relative-host-path hostname rpath)
  (string-append (base-path) "/hosts/" hostname rpath))

(define (files path)
  (let ((files (scandir path)))
    (filter (lambda (file) (stat:type=? (stat file) 'regular))
	    (map (lambda (file) (string-append path "/" file)) files))))

(define (relative-files rpath)
  (files (relative-path rpath)))

(define (relative-host-files hostname rpath)
  (files (relative-host-path hostname rpath)))

(define (load-by-hostname hostname type)
  (let* ((path (relative-host-path hostname (string-append "/" type ".scm"))))
    (cond
     ((access? path R_OK)
      (load path))
     (else
      (load (string-append "./hosts/default-" type ".scm" ))))))

