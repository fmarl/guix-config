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
  (define-values (black white bright-black bright-white)
                 (if (theme-dark? theme)
                     (values 'bg_1
                             'fg_0
                             'bg_active
                             'dim_0)
                     (values 'fg_0
                             'bg_active
                             'dim_0
                             'bg_1)))

  (toml-file "alacritty.toml"
             `(("font" ("size" . 12))
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

               ("colors.primary" ,@(color-entries theme
                                                  '(("background" . bg_0)
                                                    ("foreground" . fg_0))))

               ("colors.cursor" ,@(color-entries theme
                                                 '(("cursor" . cursor)
                                                   ("text" . bg_0))))

               ("colors.selection" ,@(color-entries theme
                                                    '(("background" . bg_region)
                                                      ("text" . fg_0))))

               ("colors.normal" ,@(color-entries theme
                                                 `(("black" unquote black)
                                                   ("red" . red)
                                                   ("green" . green)
                                                   ("yellow" . yellow)
                                                   ("blue" . blue)
                                                   ("magenta" . magenta)
                                                   ("cyan" . cyan)
                                                   ("white" unquote white))))

               ("colors.bright" ,@(color-entries theme
                                                 `(("black" unquote
                                                    bright-black)
                                                   ("red" . br_red)
                                                   ("green" . br_green)
                                                   ("yellow" . br_yellow)
                                                   ("blue" . br_blue)
                                                   ("magenta" . br_magenta)
                                                   ("cyan" . br_cyan)
                                                   ("white" unquote
                                                    bright-white)))))))

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
