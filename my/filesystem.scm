(define-module (my filesystem)
  #:use-module (gnu system file-systems)
  #:export (btrfs-filesystems))

(define* (btrfs-filesystems dev-identifier fsmap #:optional (deps '()))
  (map (lambda (item)
	 (let* ((item-mount-point (car item))
		(item-options (car (cdr item))))
	   (if (and
		(string=? (string-take-right item-mount-point 1) "/")
		(not (string=? item-mount-point "/")))
	       (throw 'mount-point-error
		      (format #f "Mountpoint ~A shouldn't end with a /" item-mount-point)))
           (file-system
            (device dev-identifier)
            (mount-point item-mount-point)
            (type "btrfs")
            (options item-options)
            (dependencies deps))))
       fsmap))
