;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

;; Development shell: `guix shell` in this directory, or direnv (.envrc)
(specifications->manifest
 (list "make"
       "git"
       "guile"))
