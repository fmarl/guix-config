(define-module (common system virtualization)
  #:use-module (gnu services)
  #:use-module (gnu services linux)
  #:export (kvm-services))

;; KVM for VMs started by the user (see ~/src/guix-vms), who needs to be in
;; the kvm group.  MODULE is "kvm_amd" or "kvm_intel".  On AMD, SVM must be
;; enabled in the firmware setup.
(define (kvm-services module)
  (list (simple-service 'kvm kernel-module-loader-service-type
                        (list module))))
