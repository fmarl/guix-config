(define-module (my home emacs)
  #:use-module (gnu packages)
  #:use-module (gnu packages emacs)
  #:use-module (gnu packages emacs-build)
  #:use-module (gnu packages emacs-xyz)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:use-module (gnu home services)
  #:use-module (gnu home services shepherd)
  #:use-module (guix gexp)
  #:use-module (guix packages)
  #:export (%emacs-packages %emacs-services))

(define (emacs-file fname)
  (string-append ".emacs.d/" fname))

(define emacs-client-tty
  (program-file "emacs-client-tty"
                #~(apply system*
                         #$(file-append emacs-next-pgtk "/bin/emacsclient")
                         "--tty"
                         (cdr (command-line)))))

(define emacs-client-new-frame
  (program-file "emacs-client-new-frame"
                #~(apply system*
                         #$(file-append emacs-next-pgtk "/bin/emacsclient")
                         "--create-frame"
			 (string-append "--alternate-editor=\"\"")
                         (cdr (command-line)))))

(define emacs-daemon-service
  (simple-service 'emacs-daemon home-shepherd-service-type
		  (list (shepherd-service
			 (provision '(emacs-daemon))
			 (start #~(make-forkexec-constructor
				   (list #$(file-append emacs-next-pgtk "/bin/emacs")
					 "--fg-daemon=emacs-daemon")))
			 
			 (stop #~(make-system-destructor
				  #$(file-append emacs-next-pgtk
						 "/bin/emacsclient" " "
						 "--socket-name=emacs-daemon"
						 " " "--eval '(kill-emacs)'")))
			 (documentation (string-append "Emacs background daemon"))))))

(define emacs-client-as-editor-service
  (simple-service 'emacs-set-default-editor
                  home-environment-variables-service-type
		  `(("ALTERNATE_EDITOR" . ,emacs-client-tty)
                    ("VISUAL" . ,emacs-client-new-frame))))

(define emacs-packages
   (specifications->packages
    (list
     "emacs-ef-themes"
     "emacs-ace-window"
     "emacs-avy"
     "emacs-envrc"
     "emacs-posframe"
     "emacs-magit"
     "emacs-dirvish"
     "emacs-yasnippet"
     "emacs-yasnippet-snippets"
     "emacs-markdown-mode"
     "emacs-paredit"
     "emacs-rainbow-delimiters"
     "emacs-marginalia"
     "emacs-orderless"
     "emacs-embark"
     "emacs-wgrep"
     "emacs-apheleia"
     "emacs-consult"
     "emacs-vertico"
     "emacs-consult-eglot"
     "emacs-cape"
     "emacs-corfu"
     "emacs-diff-hl"
     "emacs-meow"
     "emacs-org-modern"
     "emacs-denote"
     "emacs-eat"
     
     ;; Clojure
     "emacs-cider"

     ;; Common Lisp
     "emacs-sly"

     ;; Zig
     "emacs-zig-mode"

     ;; OCaml
     "emacs-tuareg"

     ;; Utils
     "emacs-guix"
     "emacs-geiser"
     "emacs-circe"
     "emacs-elfeed"
     "emacs-app-launcher"
     
     ;; Treesitter
     "tree-sitter-rust"
     "tree-sitter-zig"
     "tree-sitter-clojure"
     )))

(define-public %emacs-packages
  (append
   (specifications->packages
    (list "emacs-next-pgtk"))
   emacs-packages))

(define-public %emacs-services
  (list
   emacs-daemon-service
   emacs-client-as-editor-service))
