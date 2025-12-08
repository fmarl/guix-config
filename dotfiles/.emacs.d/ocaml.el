(use-package tuareg
  :defer t
  :mode (("\\.ocamlinit\\'" . tuareg-mode)))

(use-package utop
  :config
  (add-hook 'tuareg-mode-hook #'utop-minor-mode))

(use-package dune)
