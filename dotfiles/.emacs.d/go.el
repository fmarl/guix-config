;;; go.el --- Go development setup -*- lexical-binding: t; -*-

;; LSP & Go Tools
(use-package go-mode
  :ensure t
  :hook ((go-mode . lsp-deferred)
         (go-mode . (lambda ()
                      (setq tab-width 4)
                      (setq indent-tabs-mode t))))
  :config
  ;; Format on save using goimports
  (setq gofmt-command "goimports")
  (add-hook 'before-save-hook 'gofmt-before-save))

(use-package lsp-mode
  :after go-mode
  :commands (lsp lsp-deferred)
  :hook (go-mode . lsp-deferred)
  :custom
  (lsp-go-gopls-server-path "gopls")
  (lsp-prefer-flymake nil))

(use-package lsp-ui
  :after lsp-mode
  :commands lsp-ui-mode
  :hook (lsp-mode . lsp-ui-mode)
  :custom
  (lsp-ui-doc-enable t)
  (lsp-ui-sideline-enable t)
  :bind (:map lsp-ui-mode-map
              ("M-." . lsp-ui-peek-find-definitions)
              ("M-," . lsp-ui-peek-find-references)))

(use-package company
  :hook (go-mode . company-mode)
  :custom
  (company-idle-delay 0.0)
  (company-minimum-prefix-length 1))

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
(use-package go-test
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
