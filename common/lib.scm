(define-module (common lib)
  #:export (host-config))

(define* (host-config type #:optional (hostname (gethostname)))
  "Return %system or %home (TYPE is \"system\" or \"home\") of the module
(hosts HOSTNAME TYPE), falling back to (hosts default TYPE)."
  (let* ((type (string->symbol type))
         (module (or (resolve-module `(hosts ,(string->symbol hostname) ,type)
                                     #:ensure #f)
                     (resolve-module `(hosts default ,type) #:ensure #f)
                     (error "no configuration for host" hostname type))))
    (module-ref module (symbol-append '% type))))
