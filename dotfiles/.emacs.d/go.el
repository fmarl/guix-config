;;; go.el --- Go development setup -*- lexical-binding: t; -*-

;; LSP & Go Tools
(use-package go-mode
  :ensure t
  :hook ((go-mode . (lambda ()
                      (setq tab-width 4)
                      (setq indent-tabs-mode t))))
  :config
  ;; Format on save using goimports
  (setq gofmt-command "goimports")
  (add-hook 'before-save-hook 'gofmt-before-save))

(use-package yasnippet
  :hook (go-mode . yas-minor-mode))

;; Golang Linting & Formatting
(use-package flycheck
  :hook (go-mode . flycheck-mode))

;; Delve Debugging
(use-package go-dlv
  :ensure t
  :commands go-dlv)

;; Go Test Integration
(use-package gotest
  :ensure t
  :commands (go-test-current-test go-test-current-file go-test-current-project)
  :bind (:map go-mode-map
              ("C-c t t" . go-test-current-test)
              ("C-c t f" . go-test-current-file)
              ("C-c t p" . go-test-current-project)))

;; Optional: gotools autocompletion integration
(use-package go-eldoc
  :hook (go-mode . go-eldoc-setup))

(provide 'go)
