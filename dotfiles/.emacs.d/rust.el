(use-package rustic
  :defer t
  :init
  (setq rustic-lsp-server 'rust-analyzer)
  (setq rustic-format-on-save t)
  :config
  (add-hook 'rustic-mode-hook #'lsp-deferred)
  (add-hook 'lsp-mode-hook #'yas-minor-mode)
  ;; configure inlay hints und andere Optionen
  (setq lsp-rust-analyzer-display-parameter-hints t
        lsp-rust-analyzer-display-closure-return-type-hints t
        lsp-rust-analyzer-display-chaining-hints t)
  )

(with-eval-after-load 'rustic
  (define-key rustic-mode-map (kbd "C-c C-c c") #'rustic-cargo-check)
  (define-key rustic-mode-map (kbd "C-c C-c r") #'rustic-cargo-run))
