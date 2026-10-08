;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common themes)
  #:use-module (guix records)
  #:export (theme-dark?
            ef-owl
            modus-operandi-tinted
            color))

(define-record-type* <theme> theme make-theme
  theme?
  (dark?  theme-dark?)
  (colors theme-colors))

(define ef-owl
  (theme
   (dark? #t)
   (colors
    '((bg_0 . "292c2f")
      (bg_1 . "373b3d")
      (bg_2 . "40474b")
      (bg_popup . "33363a")
      (bg_region . "404f66")
      (bg_accent . "4f509f")
      (bg_active . "60676b")
      (border . "4f5f66")
      (cursor . "afe6ef")
      (dim_0 . "857f8f")
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
  (theme
   (dark? #f)
   (colors
    '((bg_0 . "fbf7f0")
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

(define (color theme name)
  "Return the color NAME of THEME as #rrggbb."
  (string-append "#" (assq-ref (theme-colors theme) name)))
