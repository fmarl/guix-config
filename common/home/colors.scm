;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common home colors)
  #:export (%colors color))

(define %colors
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
    (br_violet . "d389af")))

(define (color name)
  "Return the color NAME as #rrggbb."
  (string-append "#" (assq-ref %colors name)))
