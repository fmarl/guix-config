(use-modules (gnu home))

(add-to-load-path (dirname (current-filename)))

(let ((hostname (utsname:nodename (uname))))
  (cond
   ((string=? hostname "workstation")
    (load "./hosts/workstation/home.scm"))
   (else
    (load "./hosts/default-home.scm"))))