(add-to-load-path (dirname (current-filename)))

(use-modules (gnu)
	     (my lib))

(let ((hostname (utsname:nodename (uname))))
  (load-by-hostname hostname "system"))
