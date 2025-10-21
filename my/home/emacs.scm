(define-module (my home emacs)
  #:use-module (gnu packages)
  #:use-module (gnu packages emacs)
  #:use-module (gnu packages emacs-build)
  #:use-module (gnu packages emacs-xyz)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:use-module (guix gexp)
  #:use-module (guix packages)
  #:export (%emacs-packages %emacs-services))

(define (emacs-file fname)
  (string-append ".emacs.d/" fname))

(define emacs-client-tty
  (program-file "emacs-client-tty"
                #~(apply system*
                         #$(file-append emacs "/bin/emacsclient")
                         "--tty"
                         (cdr (command-line)))))
(define emacs-client-new-frame
  (program-file "emacs-client-new-frame"
                #~(apply system*
                         #$(file-append emacs "/bin/emacsclient")
                         "--create-frame"
			 (string-append "--alternate-editor=\"\"")
                         (cdr (command-line)))))


(define emacs-service
  (simple-service 'emacs-config
                  home-files-service-type
                  `((,(emacs-file "init.el")
                     ,(local-file "../../dotfiles/.emacs.d/init.el"))
		    (,(emacs-file "cc.el")
                     ,(local-file "../../dotfiles/.emacs.d/cc.el"))
		    (,(emacs-file "clojure.el")
		     ,(local-file "../../dotfiles/.emacs.d/clojure.el"))
		    (,(emacs-file "completion.el")
		     ,(local-file "../../dotfiles/.emacs.d/completion.el"))
		    (,(emacs-file "eglot.el")
		     ,(local-file "../../dotfiles/.emacs.d/eglot.el"))
		    (,(emacs-file "magit.el")
		     ,(local-file "../../dotfiles/.emacs.d/magit.el"))
		    (,(emacs-file "rust.el")
		     ,(local-file "../../dotfiles/.emacs.d/rust.el"))
		    (,(emacs-file "scheme.el")
		     ,(local-file "../../dotfiles/.emacs.d/scheme.el"))
		    (,(emacs-file "org.el")
		     ,(local-file "../../dotfiles/.emacs.d/org.el"))
		    )))

(define emacs-client-as-editor-service
  (simple-service 'emacs-set-default-editor
                  home-environment-variables-service-type
		  `(("ALTERNATE_EDITOR" . ,emacs-client-tty)
                    ("VISUAL" . ,emacs-client-new-frame))))

(define emacs-packages
  (specifications->packages
   (list
    "emacs-use-package"
    "emacs-zenburn-theme"
    "emacs-moody"
    "emacs-smex"
    "emacs-ace-window"
    "emacs-avy"
    "emacs-direnv"
    "emacs-posframe"
    "emacs-magit"
    "emacs-projectile"
    "emacs-dirvish"
    "emacs-dap-mode"
    "emacs-yasnippet"
    "emacs-yasnippet-snippets"
    "emacs-markdown-mode"
    "emacs-eat"
    "emacs-paredit"
    "emacs-rainbow-delimiters"
    "emacs-marginalia"
    "emacs-orderless"
    "emacs-embark"
    "emacs-consult"
    "emacs-vertico"
    "emacs-consult-eglot"
    "emacs-kind-icon"
    "emacs-cape"
    "emacs-corfu"
    "emacs-clang-format"
    "emacs-rustic"
    "emacs-rust-mode"
    "emacs-geiser"
    "emacs-guix"
    )
   )
  )

(define-public %emacs-packages
  (append
   (specifications->packages
    (list "emacs"))
   emacs-packages))

(define-public %emacs-services
  (list emacs-service emacs-client-as-editor-service))
