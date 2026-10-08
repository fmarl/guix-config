;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common home theme)
  #:use-module (guix gexp)
  #:use-module (gnu packages fonts)
  #:use-module (gnu packages gnome)
  #:use-module (gnu packages gnome-xyz)
  #:use-module (nongnu packages fonts)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:use-module (common home helpers)
  #:use-module (common themes)
  #:export (theme-services %cursor-theme))

(define %cursor-theme "Adwaita")

(define (gtk-settings theme)
  (plain-file "settings.ini"
	      (string-append "[Settings]
gtk-theme-name=" (if (theme-dark? theme) "adw-gtk3-dark" "adw-gtk3") "
gtk-icon-theme-name=" (if (theme-dark? theme) "Papirus-Dark" "Papirus") "
gtk-cursor-theme-name=" %cursor-theme "
gtk-cursor-theme-size=24
gtk-font-name=Aporetic Sans 11
gtk-application-prefer-dark-theme=" (if (theme-dark? theme) "1" "0") "
")))

(define (gtk-css theme)
  (plain-file
   "gtk.css"
   (string-concatenate
    (map (lambda (entry)
	   (string-append "@define-color " (car entry) " "
			  (color theme (cdr entry)) ";\n"))
	 '(("accent_color" . br_blue)
	   ("accent_bg_color" . bg_accent)
	   ("accent_fg_color" . fg_0)
	   ("window_bg_color" . bg_0)
	   ("window_fg_color" . fg_0)
	   ("view_bg_color" . bg_0)
	   ("view_fg_color" . fg_0)
	   ("headerbar_bg_color" . bg_1)
	   ("headerbar_fg_color" . fg_0)
	   ("headerbar_backdrop_color" . bg_0)
	   ("sidebar_bg_color" . bg_1)
	   ("sidebar_fg_color" . fg_0)
	   ("card_bg_color" . bg_1)
	   ("card_fg_color" . fg_0)
	   ("dialog_bg_color" . bg_1)
	   ("dialog_fg_color" . fg_0)
	   ("popover_bg_color" . bg_popup)
	   ("popover_fg_color" . fg_0)
	   ("destructive_color" . red)
	   ("success_color" . green)
	   ("warning_color" . yellow)
	   ("error_color" . red))))))

(define (theme-services theme)
  (list (home-packages adw-gtk3-theme
		       papirus-icon-theme
		       adwaita-icon-theme
		       ;; waybar uses Font Awesome 6 and powerline glyphs
		       font-awesome-nonfree
		       font-nerd-symbols)
	(simple-service 'gtk-theme
			home-xdg-configuration-files-service-type
			`(("gtk-3.0/settings.ini" ,(gtk-settings theme))
			  ("gtk-3.0/gtk.css" ,(gtk-css theme))
			  ("gtk-4.0/settings.ini" ,(gtk-settings theme))
			  ("gtk-4.0/gtk.css" ,(gtk-css theme))))
	(simple-service 'cursor-theme
			home-environment-variables-service-type
			`(("XCURSOR_THEME" . ,%cursor-theme)
			  ("XCURSOR_SIZE" . "24")))))
