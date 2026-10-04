(define-module (common home emacs)
  #:use-module (gnu packages emacs)
  #:use-module (gnu packages emacs-xyz)
  #:use-module (gnu packages ocaml)
  #:use-module (gnu packages tree-sitter)
  #:use-module (sagittarius locked mail)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:use-module (gnu home services shepherd)
  #:use-module (guix gexp)
  #:use-module (srfi srfi-1)
  #:use-module (common home helpers)
  #:export (%emacs-socket
            emacsclient-command
            %emacs-services))

(define %emacs-socket "emacs-daemon")

(define emacsclient (file-append emacs-next-pgtk "/bin/emacsclient"))

(define (emacsclient-command . arguments)
  "Return the emacsclient command line connecting to the daemon, as a list."
  (cons* emacsclient "-s" %emacs-socket arguments))

(define emacs-daemon-service
  (simple-service 'emacs-daemon home-shepherd-service-type
                  (list (shepherd-service
                         (provision '(emacs-daemon))
                         (start #~(make-forkexec-constructor
                                   (list #$(file-append emacs-next-pgtk "/bin/emacs")
                                         #$(string-append "--fg-daemon=" %emacs-socket))))
                         (stop #~(make-system-destructor
                                  #$(file-append emacs-next-pgtk
                                                 "/bin/emacsclient"
                                                 " --socket-name=" %emacs-socket
                                                 " --eval '(kill-emacs)'")))
                         (documentation "Emacs background daemon")))))

(define (emacsclient-script name . arguments)
  (apply shell-script name "exec "
         (append (append-map (lambda (argument) (list argument " "))
                             (apply emacsclient-command arguments))
                 '("\"$@\"\n"))))

(define emacs-editor-service
  (simple-service 'emacs-editor
                  home-environment-variables-service-type
                  `(("EDITOR" . ,(emacsclient-script "emacs-tty" "-t"))
                    ("VISUAL" . ,(emacsclient-script "emacs-frame" "-c")))))

(define emacs-packages
  (list
   emacs-ef-themes
   emacs-ace-window
   emacs-avy
   emacs-envrc
   emacs-posframe
   emacs-magit
   emacs-dirvish
   emacs-yasnippet
   emacs-yasnippet-snippets
   emacs-markdown-mode
   emacs-paredit
   emacs-rainbow-delimiters
   emacs-marginalia
   emacs-orderless
   emacs-embark
   emacs-wgrep
   emacs-apheleia
   emacs-consult
   emacs-vertico
   emacs-consult-eglot
   emacs-cape
   emacs-corfu
   emacs-diff-hl
   emacs-meow
   emacs-org-modern
   emacs-denote
   emacs-eat

   ;; Clojure
   emacs-cider

   ;; Common Lisp
   emacs-sly

   ;; Zig
   emacs-zig-mode

   ;; Misc modes
   emacs-terraform-mode
   emacs-yaml-mode
   emacs-haskell-mode
   emacs-nasm-mode

   ;; OCaml
   emacs-tuareg

   ;; Utils
   emacs-guix
   emacs-geiser
   emacs-circe
   emacs-elfeed
   mu-locked ;mu4e
   emacs-app-launcher

   ;; Treesitter
   tree-sitter-bash
   tree-sitter-ocaml
   tree-sitter-rust
   tree-sitter-zig
   tree-sitter-clojure))

(define %emacs-services
  (list (simple-service 'emacs-packages
			home-profile-service-type
			(cons emacs-next-pgtk emacs-packages))
	emacs-daemon-service
	emacs-editor-service))
