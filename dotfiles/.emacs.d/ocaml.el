(use-package tuareg
  :defer t
  :mode (("\\.ocamlinit\\'" . tuareg-mode)))

(use-package utop
  :ensure t
  :config
  (add-hook 'tuareg-mode-hook #'utop-minor-mode))
