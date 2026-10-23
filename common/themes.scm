;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common themes)
  #:use-module (guix records)
  #:use-module (srfi srfi-1)
  #:use-module (ice-9 match)
  #:export (theme-name
            theme-dark?
            modus-operandi-tinted
            modus-vivendi-tinted
            color
            color-entries
            console-palette
            console-color
            color-rgba
            color-hex-alpha))

(define-record-type* <theme>
  theme make-theme
  theme?
  (name   theme-name)
  (dark?  theme-dark?)
  (colors theme-colors))

(define modus-operandi-tinted
  (theme
    (name 'modus-operandi-tinted)
    (dark? #f)
    (colors '((bg_0 . "fbf7f0")
              (bg_1 . "efe9dd")
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

(define modus-vivendi-tinted
  (theme
    (name 'modus-vivendi-tinted)
    (dark? #t)
    (colors '((bg_0 . "0d0e1c")
              (bg_1 . "1d2235")
              (bg_2 . "2b3045")
              (bg_popup . "14162c")
              (bg_region . "555a66")
              (bg_accent . "1640b0")
              (bg_active . "4a4f69")
              (border . "61647a")
              (cursor . "ff66ff")
              (dim_0 . "989898")
              (fg_0 . "ffffff")
              (fg_1 . "c6daff")

              (red . "ff5f59")
              (green . "44bc44")
              (yellow . "d0bc00")
              (blue . "2fafff")
              (magenta . "feacd0")
              (cyan . "00d3d0")
              (orange . "ff6b55")
              (violet . "79a8ff")

              (br_red . "ff7f86")
              (br_green . "11c777")
              (br_yellow . "dfaf7a")
              (br_blue . "00bcff")
              (br_magenta . "b6a0ff")
              (br_cyan . "6ae4b9")
              (br_orange . "fec43f")
              (br_violet . "f78fe7")))))

(define (color theme name)
  "Return the color NAME of THEME as #rrggbb."
  (string-append "#"
                 (or (assq-ref (theme-colors theme) name)
                     (error "unknown theme color" name))))

(define (color-entries theme entries)
  (map (lambda (entry)
         (cons (car entry) (color theme (cdr entry))))
       entries))

(define (color-channels theme name)
  (let ((hex (color theme name)))
    (map (lambda (start)
           (string->number (substring hex start (+ start 2)) 16))
         '(1 3 5))))

(define %console-colors
  '((black . bg_0)
    (red . red)
    (green . green)
    (yellow . yellow)
    (blue . blue)
    (magenta . magenta)
    (cyan . cyan)
    (gray . fg_1)
    (darkgray . dim_0)
    (lightred . br_red)
    (lightgreen . br_green)
    (lightyellow . br_yellow)
    (lightblue . br_blue)
    (lightmagenta . br_magenta)
    (lightcyan . br_cyan)
    (white . fg_0)))

(define (console-palette theme)
  "Return the 16 console colors of THEME as (RED GREEN BLUE) lists."
  (map (match-lambda
         ((_ . name)
          (color-channels theme name)))
       %console-colors))

(define (console-color name)
  (car (or (find (lambda (entry)
                   (eq? (cdr entry) name))
                 %console-colors)
           (error "no console color for" name))))

(define (color-rgba theme name alpha)
  "Return the color NAME of THEME with ALPHA as rgba(), as GTK CSS expects."
  (apply format #f "rgba(~a, ~a, ~a, ~a)"
         (append (color-channels theme name)
                 (list alpha))))

(define (color-hex-alpha theme name alpha)
  "Return the color NAME of THEME with ALPHA as #rrggbbaa."
  (string-append (color theme name)
                 (string-pad (number->string
                              (inexact->exact (round (* alpha 255)))
                              16)
                             2 #\0)))
