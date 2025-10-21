(use-package geiser
  :config (setq geiser-active-implementations '(guile)))

(use-package paredit :hook ((scheme-mode emacs-lisp-mode lisp-mode) . paredit-mode))
(use-package rainbow-delimiters :hook ((scheme-mode lisp-mode emacs-lisp-mode) . rainbow-delimiters-mode))
