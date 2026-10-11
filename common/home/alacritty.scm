;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common home alacritty)
  #:use-module (guix gexp)
  #:use-module (gnu home services)
  #:use-module (gnu packages terminals)
  #:use-module (common home helpers)
  #:use-module (common home theme)
  #:use-module (common home wm)
  #:use-module (common machines)
  #:use-module (common themes)
  #:export (alacritty-services))

(define (alacritty-config theme)
  (toml-file "alacritty.toml"
             `(("font" ("size" . 14))
               ("font.offset" ("x" . 0)
                ("y" . 2))

               ("font.normal" ("family" unquote %monospace-font)
                ("style" . "Regular"))

               ("font.bold" ("family" unquote %monospace-font)
                ("style" . "Bold"))

               ("font.italic" ("family" unquote %monospace-font)
                ("style" . "Italic"))

               ("font.bold_italic" ("family" unquote %monospace-font)
                ("style" . "Bold Italic"))

               ("window" ("dynamic_padding" . #t))

               ("window.padding" ("x" . 12)
                ("y" . 12))

               ("mouse" ("hide_when_typing" . #t))

               ("selection" ("save_to_clipboard" . #t))

               ("colors.primary" ("background" unquote
                                  (color theme
                                         'bg_0))
                ("foreground" unquote
                 (color theme
                        'fg_0)))

               ("colors.cursor" ("cursor" unquote
                                 (color theme
                                        'cursor))
                ("text" unquote
                 (color theme
                        'bg_0)))

               ("colors.selection" ("background" unquote
                                    (color theme
                                           'bg_region))
                ("text" unquote
                 (color theme
                        'fg_0)))

               ("colors.normal" ("black" unquote
                                 (color theme
                                        'bg_1))
                ("red" unquote
                 (color theme
                        'red))
                ("green" unquote
                 (color theme
                        'green))
                ("yellow" unquote
                 (color theme
                        'yellow))
                ("blue" unquote
                 (color theme
                        'blue))
                ("magenta" unquote
                 (color theme
                        'magenta))
                ("cyan" unquote
                 (color theme
                        'cyan))
                ("white" unquote
                 (color theme
                        'fg_0)))

               ("colors.bright" ("black" unquote
                                 (color theme
                                        'bg_active))
                ("red" unquote
                 (color theme
                        'br_red))
                ("green" unquote
                 (color theme
                        'br_green))
                ("yellow" unquote
                 (color theme
                        'br_yellow))
                ("blue" unquote
                 (color theme
                        'br_blue))
                ("magenta" unquote
                 (color theme
                        'br_magenta))
                ("cyan" unquote
                 (color theme
                        'br_cyan))
                ("white" unquote
                 (color theme
                        'dim_0))))))

(define (alacritty-services machine)
  (list (home-packages alacritty)
        (simple-service 'alacritty-config
                        home-xdg-configuration-files-service-type
                        `(("alacritty/alacritty.toml" ,(alacritty-config (machine-theme
                                                                          machine)))))
        (wm-extensions machine
                       'alacritty-wm
                       (wm-bind "Mod+Shift+Return"
                                (list (file-append alacritty "/bin/alacritty"))
                                #:title "Open alacritty"))))
