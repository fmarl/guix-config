(define-module (my lib))

(define-public (load-by-hostname hostname type)
  (let* ((base-path (dirname (current-filename)))
	(path  (string-append base-path "/../hosts/" hostname "/" type ".scm")))
    (display path)
    (cond
     ((access? path R_OK)
      (load path))
     (else
      (load (string-append "./hosts/default-" type ".scm" ))))))
