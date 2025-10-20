(use-package zig-mode
  :mode "\\.zig\\'"
  :hook (zig-mode . lsp-deferred)
  :config
  (setq lsp-zig-zls-executable "zls"))
