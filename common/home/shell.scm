;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common home shell)
  #:use-module (gnu home services)
  #:use-module (gnu home services shells)
  #:use-module (gnu packages admin)
  #:use-module (gnu packages rust-apps)
  #:use-module (gnu packages shellutils)
  #:use-module (gnu packages terminals)
  #:use-module (gnu services)
  #:use-module (common files)
  #:use-module (common home helpers)
  #:use-module (common locale)
  #:export (%shell-services))

(define locale-variables
  (simple-service 'locale-variables home-environment-variables-service-type
                  (map (lambda (var)
                         (cons var (string-append %regional-locale ".UTF-8")))
                       '("LC_ADDRESS"
                         "LC_IDENTIFICATION"
                         "LC_MEASUREMENT"
                         "LC_MONETARY"
                         "LC_NAME"
                         "LC_NUMERIC"
                         "LC_PAPER"
                         "LC_TELEPHONE"
                         "LC_TIME"))))

(define fzf-command
  "rg --files --hidden --glob '!.git' --glob '!.direnv' --glob '!.cache'")

(define fzf-variables
  (simple-service 'fzf-variables home-environment-variables-service-type
                  `(("FZF_DEFAULT_COMMAND" . ,fzf-command)
                    ("FZF_CTRL_T_COMMAND" . ,fzf-command))))

(define %shell-services
  (list (home-packages direnv fzf ripgrep htop zsh-syntax-highlighting)
        (service home-zsh-service-type
                 (home-zsh-configuration
                  (zshrc (list (config-file "dotfiles/.zshrc" "zshrc")))))
        locale-variables
        fzf-variables))
