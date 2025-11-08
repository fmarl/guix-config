(require 'package)
(package-initialize)

(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))
(eval-when-compile (require 'use-package))
(setq use-package-always-ensure t
      use-package-expand-minimally t
      use-package-compute-statistics t
      custom-safe-themes t)

(setq gc-cons-threshold (* 100 1024 1024)
      read-process-output-max (* 1024 1024)
      inhibit-startup-screen t
      native-comp-async-report-warnings-errors nil)

(set-language-environment "UTF-8")
(set-default-coding-systems 'utf-8)

(tool-bar-mode -1)
(menu-bar-mode -1)
(scroll-bar-mode -1)
(column-number-mode 1)
(global-display-line-numbers-mode 1)
(show-paren-mode 1)
(electric-pair-mode 1)
(global-prettify-symbols-mode 1)
;; (set-frame-font "Source Code Pro:size=14")
(set-cursor-color "#ffffff")
(setq ring-bell-function 'ignore)

;; Backup und Auto-Save
(setq backup-directory-alist '((".*" . "~/.saves/"))
      auto-save-default nil)

;; Theme
(use-package zenburn-theme
  :config (load-theme 'zenburn t))

;; Mode Line
(use-package moody
  :config
  (moody-replace-mode-line-front-space)
  (moody-replace-mode-line-buffer-identification)
  (moody-replace-vc-mode))

;; Which-key (Shortcut-Hilfe)
(use-package which-key :config (which-key-mode))

;; Projectile (Projektmanagement)
(use-package projectile
  :init (projectile-mode +1)
  :bind-keymap ("C-c p" . projectile-command-map))

;; File Explorer
(use-package dirvish
  :init (dirvish-override-dired-mode)
  :config
  (setq dirvish-default-layout '(0 0.3 0.7)
        dirvish-attributes '(subtree-state collapse git-msg)))

;; Ace / Jump Navigation
(use-package ace-window :bind (("M-p" . ace-window)))
(use-package avy
  :bind (("C-:" . avy-goto-char-timer)
	 ("M-g -" . avy-kill-region)
	 ("M-g =" . avy-move-region)
	 ("M-g +" . avy-copy-region)))

;; Smex (M-x)
(use-package smex
  :init (smex-initialize)
  :bind (("M-x" . smex)
         ("M-X" . smex-major-mode-commands)))

;; Markdown
(use-package markdown-mode :mode "\\.md\\'")

;; Terminal
(use-package eat)

;; Direnv
(use-package direnv
  :config (direnv-mode))

(use-package consult
  :bind (;; C-c bindings in `mode-specific-map'
         ("C-c M-x" . consult-mode-command)
         ("C-c h" . consult-history)
         ("C-c k" . consult-kmacro)
         ("C-c m" . consult-man)
         ("C-c i" . consult-info)
         ([remap Info-search] . consult-info)
         ;; C-x bindings in `ctl-x-map'
         ("C-x M-:" . consult-complex-command) ;; orig. repeat-complex-command
         ("C-x b" . consult-buffer) ;; orig. switch-to-buffer
         ("C-x 4 b" . consult-buffer-other-window) ;; orig. switch-to-buffer-other-window
         ("C-x 5 b" . consult-buffer-other-frame) ;; orig. switch-to-buffer-other-frame
         ("C-x t b" . consult-buffer-other-tab)	;; orig. switch-to-buffer-other-tab
         ("C-x r b" . consult-bookmark)		;; orig. bookmark-jump
         ("C-x p b" . consult-project-buffer) ;; orig. project-switch-to-buffer
         ;; Custom M-# bindings for fast register access
         ("M-#" . consult-register-load)
         ("M-'" . consult-register-store) ;; orig. abbrev-prefix-mark (unrelated)
         ("C-M-#" . consult-register)
         ;; Other custom bindings
         ("M-y" . consult-yank-pop) ;; orig. yank-pop
         ;; M-g bindings in `goto-map'
         ("M-g e" . consult-compile-error)
         ("M-g r" . consult-grep-match)
         ("M-g f" . consult-flymake) ;; Alternative: consult-flycheck
         ("M-g g" . consult-goto-line)	 ;; orig. goto-line
         ("M-g M-g" . consult-goto-line) ;; orig. goto-line
         ("M-g o" . consult-outline) ;; Alternative: consult-org-heading
         ("M-g m" . consult-mark)
         ("M-g k" . consult-global-mark)
         ("M-g i" . consult-imenu)
         ("M-g I" . consult-imenu-multi)
         ;; M-s bindings in `search-map'
         ("M-f d" . consult-find) ;; Alternative: consult-fd
         ("M-f c" . consult-locate)
         ("M-f g" . consult-grep)
         ("M-f G" . consult-git-grep)
         ("M-f r" . consult-ripgrep)
         ("M-f l" . consult-line)
         ("M-f L" . consult-line-multi)
         ("M-f k" . consult-keep-lines)
         ("M-f u" . consult-focus-lines)
         ;; Isearch integration
         ("M-s e" . consult-isearch-history)
         :map isearch-mode-map
         ("M-e" . consult-isearch-history) ;; orig. isearch-edit-string
         ("M-s e" . consult-isearch-history) ;; orig. isearch-edit-string
         ("M-s l" . consult-line) ;; needed by consult-line to detect isearch
         ("M-s L" . consult-line-multi)	;; needed by consult-line to detect isearch
         ;; Minibuffer history
         :map minibuffer-local-map
         ("M-s" . consult-history) ;; orig. next-matching-history-element
         ("M-r" . consult-history))                ;; orig. previous-matching-history-element

  :hook (completion-list-mode . consult-preview-at-point-mode)
  :init
  (define-prefix-command 'my/search-map)
  (global-set-key (kbd "M-f") 'my/search-map)
  (advice-add #'register-preview :override #'consult-register-window)
  (setq register-preview-delay 0.5)
  (setq xref-show-xrefs-function #'consult-xref
        xref-show-definitions-function #'consult-xref)

  :config
  (consult-customize
   consult-theme :preview-key '(:debounce 0.2 any)
   consult-ripgrep consult-git-grep consult-grep consult-man
   consult-bookmark consult-recent-file consult-xref
   consult--source-bookmark consult--source-file-register
   consult--source-recent-file consult--source-project-recent-file
   :preview-key '(:debounce 0.4 any))
  (setq consult-narrow-key "<") ;; "C-+"
  (setq consult-ripgrep-command
	"rg --null --line-buffered --color=never --max-columns=1000 --path-separator --smart-case --no-heading --with-filename --line-number --search-zip --hidden --glob '!.git/*' --glob '!.direnv/*'")
  )

(use-package marginalia
  :init (marginalia-mode))

(use-package orderless
  :init
  (setq completion-styles '(orderless)
        completion-category-defaults nil
        completion-category-overrides '((file (styles orderless)))))

(use-package vertico
  :init (vertico-mode))

(defun load-conf-file (file)
  (interactive "f")
  (load-file (concat (concat (getenv "HOME") "/.emacs.d/") file)))

(load-conf-file "completion.el")
(load-conf-file "eglot.el")
(load-conf-file "rust.el")
(load-conf-file "scheme.el")
(load-conf-file "magit.el")
(load-conf-file "cc.el")
(load-conf-file "org.el")
(load-conf-file "circe.el")
(load-conf-file "mu4e.el")

(add-to-list 'auto-mode-alist
             '("\\.json\\'" . (lambda ()
                                (javascript-mode)
                                (json-pretty-print (point-min) (point-max))
                                (goto-char (point-min))
                                (set-buffer-modified-p nil))))

(provide 'init)
