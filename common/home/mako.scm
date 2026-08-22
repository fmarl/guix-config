;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common home mako)
  #:use-module (guix gexp)
  #:use-module (gnu packages window-management)
  #:use-module (gnu packages gnome)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:use-module (common home helpers)
  #:use-module (common home wm)
  #:use-module (common machines)
  #:use-module (common themes)
  #:export (mako-services))

(define (mako-config theme)
  (plain-file "mako-config"
	      (string-append "background-color=" (color theme 'bg_2) "\n"
			     "text-color=" (color theme 'fg_0) "\n"
			     "border-color=" (color theme 'bg_1) "\n"
			     "border-radius=12\n"
			     "progress-color=" (color theme 'cyan) "\n")))

(define (mako-services machine)
  (list (home-packages mako libnotify)
	(simple-service 'mako-config
			home-xdg-configuration-files-service-type
			`(("mako/config" ,(mako-config (machine-theme machine)))))
	(wm-extensions (machine-wm machine) 'mako-autostart
		       (wm-autostart (file-append mako "/bin/mako")))))
