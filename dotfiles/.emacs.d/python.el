;;; python.el --- Python development setup -*- lexical-binding: t; -*-

(use-package python
  :ensure t
  :hook ((python-mode . (lambda ()
                          (setq tab-width 4)
                          (setq python-indent-offset 4))))
  :config
  ;; Autoformat using black on save
  (use-package blacken
    :hook (python-mode . blacken-mode)
    :custom
    (blacken-allow-py36 t)
    (blacken-line-length 88)))

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
