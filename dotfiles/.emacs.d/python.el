;;; python.el --- Python development setup -*- lexical-binding: t; -*-

(use-package python
  :ensure t
  :hook ((python-mode . lsp-deferred)
         (python-mode . (lambda ()
                          (setq tab-width 4)
                          (setq python-indent-offset 4))))
  :config
  ;; Autoformat using black on save
  (use-package blacken
    :hook (python-mode . blacken-mode)
    :custom
    (blacken-allow-py36 t)
    (blacken-line-length 88)))

;; LSP (pyright)
(use-package lsp-mode
  :after python
  :commands (lsp lsp-deferred)
  :hook (python-mode . lsp-deferred)
  :custom
  (lsp-python-pyright-executable "pyright")
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

;; Autocompletion
(use-package company
  :hook (python-mode . company-mode)
  :custom
  (company-idle-delay 0.0)
  (company-minimum-prefix-length 1))

;; Snippets
(use-package yasnippet
  :hook (python-mode . yas-minor-mode))
(use-package yasnippet-snippets)

;; Linting with ruff
(use-package flycheck
  :hook (python-mode . flycheck-mode)
  :config
  (setq flycheck-python-pycompile-executable "python3")
  (setq flycheck-python-flake8-executable "ruff"))

(provide 'python)
;;; python.el ends here
