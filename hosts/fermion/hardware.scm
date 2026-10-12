(define-module (hosts fermion hardware)
  #:use-module (gnu)
  #:use-module (common system filesystem)
  #:export (%mapped-devices %file-systems))

(define %mapped-devices
  '())

(define %file-systems
  (impermanent-file-systems (uuid "66adccf5-1a02-435e-93a9-044b95955e89"
                                  'btrfs)
                            #:esp "C159-4A51"
                            #:subvolumes '(("/srv/backup" "@backup" no-suid
                                            no-dev no-exec))))
