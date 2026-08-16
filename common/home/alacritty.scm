;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common home alacritty)
  #:use-module (gnu packages terminals)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:use-module (common home helpers)
  #:use-module (common themes)
  #:export (alacritty-services))

(define (alacritty-config theme)
  (toml-file
   "alacritty.toml"
   `(("font"
      ("size" . 12))
     ("font.normal"
      ("family" . "Aporetic Sans Mono"))
     ("window.padding"
      ("x" . 8)
      ("y" . 8))
     ("mouse"
      ("hide_when_typing" . #t))
     ("selection"
      ("save_to_clipboard" . #t))
     ("colors.primary"
      ("background" . ,(color theme 'bg_0))
      ("foreground" . ,(color theme 'fg_0)))
     ("colors.cursor"
      ("cursor" . ,(color theme 'cursor))
      ("text" . ,(color theme 'bg_0)))
     ("colors.selection"
      ("background" . ,(color theme 'bg_region))
      ("text" . ,(color theme 'fg_0)))
     ("colors.normal"
      ("black" . ,(color theme 'bg_1))
      ("red" . ,(color theme 'red))
      ("green" . ,(color theme 'green))
      ("yellow" . ,(color theme 'yellow))
      ("blue" . ,(color theme 'blue))
      ("magenta" . ,(color theme 'magenta))
      ("cyan" . ,(color theme 'cyan))
      ("white" . ,(color theme 'fg_0)))
     ("colors.bright"
      ("black" . ,(color theme 'bg_active))
      ("red" . ,(color theme 'br_red))
      ("green" . ,(color theme 'br_green))
      ("yellow" . ,(color theme 'br_yellow))
      ("blue" . ,(color theme 'br_blue))
      ("magenta" . ,(color theme 'br_magenta))
      ("cyan" . ,(color theme 'br_cyan))
      ("white" . ,(color theme 'dim_0))))))

(define (alacritty-services theme)
  (list (home-packages alacritty)
	(simple-service 'alacritty-config
			home-xdg-configuration-files-service-type
			`(("alacritty/alacritty.toml" ,(alacritty-config theme))))))
