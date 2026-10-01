(define-module (common home emacs)
  #:use-module (gnu packages)
  #:use-module (gnu packages emacs)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:use-module (gnu home services shepherd)
  #:use-module (guix gexp)
  #:use-module (common home helpers)
  #:export (%emacs-services))

(define emacsclient (file-append emacs-next-pgtk "/bin/emacsclient"))

(define emacs-daemon-service
  (simple-service 'emacs-daemon home-shepherd-service-type
		  (list (shepherd-service
			 (provision '(emacs-daemon))
			 (start #~(make-forkexec-constructor
				   (list #$(file-append emacs-next-pgtk "/bin/emacs")
					 "--fg-daemon=emacs-daemon")))
			 (stop #~(make-system-destructor
				  #$(file-append emacs-next-pgtk
						 "/bin/emacsclient"
						 " --socket-name=emacs-daemon"
						 " --eval '(kill-emacs)'")))
			 (documentation "Emacs background daemon")))))

(define emacs-editor-service
  (simple-service 'emacs-editor
		  home-environment-variables-service-type
		  `(("EDITOR" . ,(shell-script "emacs-tty"
					       "exec " emacsclient
					       " -s emacs-daemon -t \"$@\"\n"))
		    ("VISUAL" . ,(shell-script "emacs-frame"
					       "exec " emacsclient
					       " -s emacs-daemon -c \"$@\"\n")))))

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

     ;; Misc modes
     "emacs-terraform-mode"
     "emacs-yaml-mode"
     "emacs-haskell-mode"
     "emacs-nasm-mode"

     ;; OCaml
     "emacs-tuareg"

     ;; Utils
     "emacs-guix"
     "emacs-geiser"
     "emacs-circe"
     "emacs-elfeed"
     "mu" ;mu4e
     "emacs-app-launcher"
     
     ;; Treesitter
     "tree-sitter-bash"
     "tree-sitter-ocaml"
     "tree-sitter-rust"
     "tree-sitter-zig"
     "tree-sitter-clojure"
     )))

(define %emacs-services
  (list (simple-service 'emacs-packages
			home-profile-service-type
			(cons emacs-next-pgtk emacs-packages))
	emacs-daemon-service
	emacs-editor-service))
