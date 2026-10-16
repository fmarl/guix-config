;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common themes)
  #:use-module (guix records)
  #:use-module (srfi srfi-1)
  #:use-module (ice-9 match)
  #:export (theme-name theme-dark?
                       ef-owl
                       modus-operandi-tinted
                       color
                       color-entries
                       console-palette
                       console-color
                       color-rgba
                       color-hex-alpha))

(define-record-type* <theme> theme make-theme
  theme?
  (name theme-name)
  (dark? theme-dark?)
  (colors theme-colors))

(define ef-owl
  (theme (name 'ef-owl)
         (dark? #t)
         (colors '((bg_0 . "292c2f") (bg_1 . "373b3d")
                   (bg_2 . "40474b")
                   (bg_popup . "33363a")
                   (bg_region . "404f66")
                   (bg_accent . "4f509f")
                   (bg_active . "60676b")
                   (border . "4f5f66")
                   (cursor . "afe6ef")
                   (dim_0 . "9a94a4")
                   (fg_0 . "d0d0d0")
                   (fg_1 . "aab9af")

                   (red . "d67869")
                   (green . "70bb70")
                   (yellow . "c09f6f")
                   (blue . "80a4e0")
                   (magenta . "e5a0ea")
                   (cyan . "8fb8ea")
                   (orange . "df885f")
                   (violet . "a0a0ef")

                   (br_red . "e4959f")
                   (br_green . "60bd90")
                   (br_yellow . "cf9f90")
                   (br_blue . "72aff0")
                   (br_magenta . "cfa0e8")
                   (br_cyan . "7ac0b9")
                   (br_orange . "d1a45f")
                   (br_violet . "d389af")))))

(define modus-operandi-tinted
  (theme (name 'modus-operandi-tinted)
         (dark? #f)
         (colors '((bg_0 . "fbf7f0") (bg_1 . "efe9dd")
                   (bg_2 . "dfd5cf")
                   (bg_popup . "f6eddd")
                   (bg_region . "c2bcb5")
                   (bg_accent . "bfc9ff")
                   (bg_active . "c9b9b0")
                   (border . "9f9690")
                   (cursor . "d00000")
                   (dim_0 . "595959")
                   (fg_0 . "000000")
                   (fg_1 . "193668")

                   (red . "a60000")
                   (green . "006300")
                   (yellow . "6d5000")
                   (blue . "0031a9")
                   (magenta . "721045")
                   (cyan . "00598b")
                   (orange . "972500")
                   (violet . "3546c2")

                   (br_red . "a0132f")
                   (br_green . "00603f")
                   (br_yellow . "602938")
                   (br_blue . "0000b0")
                   (br_magenta . "531ab6")
                   (br_cyan . "005f5f")
                   (br_orange . "894000")
                   (br_violet . "8f0075")))))

(define (color theme name)
  "Return the color NAME of THEME as #rrggbb."
  (string-append "#"
                 (or (assq-ref (theme-colors theme) name)
                     (error "unknown theme color" name))))

(define (color-entries theme entries)
  (map (lambda (entry)
         (cons (car entry)
               (color theme
                      (cdr entry)))) entries))

(define (color-channels theme name)
  (let ((hex (color theme name)))
    (map (lambda (start)
           (string->number (substring hex start
                                      (+ start 2)) 16))
         '(1 3 5))))

(define %console-colors
  '((black . bg_0) (red . red)
    (green . green)
    (yellow . yellow)
    (blue . blue)
    (magenta . magenta)
    (cyan . cyan)
    (gray . fg_0)
    (darkgray . dim_0)
    (lightred . br_red)
    (lightgreen . br_green)
    (lightyellow . br_yellow)
    (lightblue . br_blue)
    (lightmagenta . br_magenta)
    (lightcyan . br_cyan)
    (white . fg_1)))

(define (console-palette theme)
  "Return the 16 console colors of THEME as (RED GREEN BLUE) lists, black as
the background and gray as the foreground."
  (map (match-lambda
         ((console . name) (color-channels theme
                                           (if (and (eq? console
                                                         'white)
                                                    (theme-dark? theme))
                                               'fg_0 name)))) %console-colors))

(define (console-color name)
  "Return the console color name showing the theme color NAME."
  (car (or (find (lambda (entry)
                   (eq? (cdr entry) name)) %console-colors)
           (error "no console color for" name))))

(define (color-rgba theme name alpha)
  "Return the color NAME of THEME with ALPHA as rgba(), as GTK CSS expects."
  (apply format #f "rgba(~a, ~a, ~a, ~a)"
         (append (color-channels theme name)
                 (list alpha))))

(define (color-hex-alpha theme name alpha)
  "Return the color NAME of THEME with ALPHA as #rrggbbaa."
  (string-append (color theme name)
                 (string-pad (number->string (inexact->exact (round (* alpha
                                                                       255)))
                                             16) 2 #\0)))
