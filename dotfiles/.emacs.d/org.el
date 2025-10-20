;;; org.el --- Modern Org-Mode Configuration -*- lexical-binding: t; -*-

(require 'org)

;; Basic Org Setup
(use-package org
  :ensure nil
  :hook ((org-mode . visual-line-mode)
         (org-mode . variable-pitch-mode)
         (org-mode . org-indent-mode)
         (org-mode . (lambda ()
                       (setq line-spacing 0.2)
                       (display-line-numbers-mode 0))))
  :mode ("\\.org\\'" . org-mode)
  :config
  (setq org-hide-emphasis-markers t
	org-pretty-entities t
	org-startup-indented t
	org-startup-folded 'content
	org-startup-with-inline-images t
	org-image-actual-width '(400)
	org-ellipsis " ▼ "
	org-log-done 'time
	org-log-into-drawer t
	org-return-follows-link t)

  ;; Todo keywords
  (setq org-todo-keywords
        '((sequence "TODO(t)" "IN-PROGRESS(i)" "|" "DONE(d)" "CANCELLED(c)"))))


(use-package org-modern
  :after org
  :ensure t
  :hook (org-mode . org-modern-mode)
  :config
  (setq org-modern-star '("◉" "○" "●" "◆" "◇" "▶")
        org-modern-table t
        org-modern-checkbox '((?X . "☑") (?- . "☒") (?\s . "☐"))
        org-modern-todo-faces
        '(("TODO" . (:foreground "#BF616A" :weight bold))
          ("IN-PROGRESS" . (:foreground "#EBCB8B" :weight bold))
          ("DONE" . (:foreground "#A3BE8C" :weight bold))
          ("CANCELLED" . (:foreground "#5E81AC" :weight normal)))))

(global-set-key (kbd "C-c a") 'org-agenda)
(global-set-key (kbd "C-c c") 'org-capture)
(global-set-key (kbd "C-c l") 'org-store-link)

(defun my/org-new-dated-file ()
  "Create a new org-mode buffer with the current date as name."
    (interactive)
  (let ((buffer-name (format "%s.org" (format-time-string "%Y-%m-%d"))))
    (switch-to-buffer (get-buffer-create buffer-name))
    (org-mode)
    (insert (format "#+TITLE: %s\n\n* TODO \n" (format-time-string "%A, %d %B %Y")))))


(provide 'org)
;;; org.el ends here
