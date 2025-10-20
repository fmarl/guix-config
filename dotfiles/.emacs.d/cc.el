(use-package cc-mode
  :ensure nil
  :hook ((c-mode c++-mode) . (lambda ()
                               (setq c-basic-offset 4)
                               (c-set-offset 'substatement-open 0))))

(use-package clang-format :defer t)
