;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(use-modules (guix channels)
             (guix describe)
             (ice-9 match)
             (srfi srfi-1))

(define (channel-commits channels)
  (map (lambda (channel)
         (cons (channel-name channel)
               (channel-commit channel))) channels))

(define locked
  (match (command-line)
    ((_ lock)
     (let ((environment (make-fresh-user-module)))
       (module-use! environment
                    (resolve-interface '(guix channels)))
       (eval (call-with-input-file lock
               read) environment)))))

(exit (lset<= equal?
              (channel-commits locked)
              (channel-commits (current-channels))))
