;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common home alacritty)
  #:use-module (gnu packages terminals)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:use-module (common home colors)
  #:use-module (common home helpers)
  #:export (%alacritty-services))

(define alacritty-config
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
      ("background" . ,(color 'bg_0))
      ("foreground" . ,(color 'fg_0)))
     ("colors.cursor"
      ("cursor" . ,(color 'cursor))
      ("text" . ,(color 'bg_0)))
     ("colors.selection"
      ("background" . ,(color 'bg_region))
      ("text" . ,(color 'fg_0)))
     ("colors.normal"
      ("black" . ,(color 'bg_1))
      ("red" . ,(color 'red))
      ("green" . ,(color 'green))
      ("yellow" . ,(color 'yellow))
      ("blue" . ,(color 'blue))
      ("magenta" . ,(color 'magenta))
      ("cyan" . ,(color 'cyan))
      ("white" . ,(color 'fg_0)))
     ("colors.bright"
      ("black" . ,(color 'bg_active))
      ("red" . ,(color 'br_red))
      ("green" . ,(color 'br_green))
      ("yellow" . ,(color 'br_yellow))
      ("blue" . ,(color 'br_blue))
      ("magenta" . ,(color 'br_magenta))
      ("cyan" . ,(color 'br_cyan))
      ("white" . ,(color 'dim_0))))))

(define %alacritty-services
  (list (home-packages alacritty)
	(simple-service 'alacritty-config
			home-xdg-configuration-files-service-type
			`(("alacritty/alacritty.toml" ,alacritty-config)))))
