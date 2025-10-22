(add-to-load-path (dirname (current-filename)))

(use-modules (gnu home)
	     (my utils))

(let ((hostname (utsname:nodename (uname))))
  (load-by-hostname hostname "home"))
