(use-package lsp-mode
  :ensure nil
  :commands (lsp lsp-deferred)
  :hook ((c-mode c++-mode rust-mode zig-mode scheme-mode) . lsp-deferred)
  :custom
  (lsp-headerline-breadcrumb-enable t)
  (lsp-diagnostics-provider :flycheck)
  (lsp-enable-snippet t)
  (lsp-idle-delay 0.2)
  (lsp-log-io nil)
  (lsp-enable-file-watchers nil)
  (lsp-response-timeout 2)
  (lsp-file-watch-threshold 5000))

(use-package lsp-ui
  :after lsp-mode
  :commands lsp-ui-mode
  :hook (lsp-mode . lsp-ui-mode)
  :custom
  (lsp-ui-doc-enable t)
  (lsp-ui-sideline-show-code-actions t)
  (lsp-ui-doc-delay 0.5)
  :bind (:map lsp-ui-mode-map
              ("M-." . lsp-ui-peek-find-definitions)
              ("M-," . lsp-ui-peek-find-references)))

(use-package lsp-ivy :after (lsp-mode ivy))

;; Optional: DAP (Debugger)
(use-package dap-mode :after lsp-mode)
