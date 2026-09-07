;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common locale)
  #:use-module (gnu system keyboard)
  #:export (%keyboard-layout %regional-locale))

(define %keyboard-layout
  (keyboard-layout "us" "altgr-intl"))

(define %regional-locale
  "de_DE")
