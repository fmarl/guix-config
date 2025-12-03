;;; eglot.el --- Modernes LSP-Setup mit Eglot + LSP-Booster -*- lexical-binding: t; -*-

(use-package eglot
  :ensure t
  :hook ((tuareg-mode rust-mode c-mode) . eglot-ensure)
  :config
  (setq eglot-sync-connect nil
        eglot-autoshutdown t
        eglot-events-buffer-size 0
        eglot-extend-to-xref t)
  
  (add-to-list 'eglot-server-programs
               '(rust-mode . ("rust-analyzer" :initializationOptions (:checkOnSave (:command "clippy")))))  (setq eldoc-echo-area-use-multiline-p t)
	       
  (add-hook 'eglot-managed-mode-hook
            (lambda ()
              (flymake-mode 1)
              (eldoc-mode 1))))

(use-package consult-eglot
  :after (consult eglot)
  :bind (:map eglot-mode-map
              ("M-." . xref-find-definitions)
              ("M-," . xref-pop-marker-stack)
	      ("M-?" . xref-find-references)
              ("C-c M-?" . consult-eglot-symbols)
              ("C-c a" . eglot-code-actions)
              ("C-c r" . eglot-rename)))

(provide 'eglot-setup)
;;; eglot.el ends here
