;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2025, 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common home emacs)
  #:use-module (guix gexp)
  #:use-module (gnu home services)
  #:use-module (gnu home services shepherd)
  #:use-module (gnu packages emacs)
  #:use-module (gnu packages emacs-xyz)
  #:use-module (gnu packages ocaml)
  #:use-module (gnu packages tree-sitter)
  #:use-module (guix-microvm packages emacs)
  #:use-module (common home helpers)
  #:use-module (common home wm)
  #:use-module (srfi srfi-1)
  #:export (%emacs-services emacs-desktop-services))

(define %emacs-socket-name
  "emacs-daemon")

(define emacsclient
  (file-append emacs-next-pgtk "/bin/emacsclient"))

(define (emacsclient-command . arguments)
  (cons* emacsclient "-s" %emacs-socket-name arguments))

(define emacs-program
  (file-append emacs-next-pgtk "/bin/emacs"))

(define emacs-daemon-shepherd-service
  (shepherd-service (provision '(emacs-daemon))
                    (start #~(make-forkexec-constructor (list #$emacs-program
                                                              #$(string-append
                                                                 "--fg-daemon="
                                                                 %emacs-socket-name))))
                    (stop #~(make-system-destructor (string-append #$emacsclient
                                                     " --socket-name="
                                                     #$%emacs-socket-name
                                                     " --eval '(kill-emacs)'")))
                    (documentation "Emacs background daemon")))

(define emacs-daemon-service
  (simple-service 'emacs-daemon home-shepherd-service-type
                  (list emacs-daemon-shepherd-service)))

(define (emacsclient-script name . arguments)
  (apply shell-script name "exec "
         (append (append-map (lambda (argument)
                               (list argument " "))
                             (apply emacsclient-command arguments))
                 '("\"$@\"\n"))))

(define emacs-tty
  (emacsclient-script "emacs-tty" "-t"))

(define emacs-editor-service
  (simple-service 'emacs-editor home-environment-variables-service-type
                  `(("EDITOR" unquote emacs-tty)
                    ("GIT_EDITOR" unquote emacs-tty)
                    ("VISUAL" unquote
                     (emacsclient-script "emacs-frame" "-c")))))

(define emacs-packages
  (list emacs-modus-themes
        emacs-ef-themes
        emacs-ace-window
        emacs-avy
        emacs-envrc
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

        emacs-cider

        emacs-sly

        emacs-gleam-mode
        emacs-haskell-mode
        emacs-nasm-mode

        emacs-tuareg
        ocaml-utop
        dune

        emacs-guix
        emacs-guix-microvm
        emacs-geiser
        emacs-circe
        emacs-elfeed

        tree-sitter-bash
        tree-sitter-gleam
        tree-sitter-json
        tree-sitter-python
        tree-sitter-rust
        tree-sitter-toml
        tree-sitter-yaml))

(define %emacs-services
  (list (simple-service 'emacs-packages home-profile-service-type
                        (cons emacs-next-pgtk emacs-packages))
        emacs-daemon-service emacs-editor-service))

(define (emacs-desktop-services machine)
  (list (wm-extensions machine
                       'emacs-wm
                       (wm-bind "Mod+E"
                                (emacsclient-command "-c" "-n")
                                #:title "Open Emacs")
                       (wm-bind "Mod+Shift+D"
                                (emacsclient-command "-c" "-n" "-e"
                                                     "(dirvish-dwim)")
                                #:title "Start dirvish"))))
