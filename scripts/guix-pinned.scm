;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

;; Exit with 0 when the running guix provides every channel of LOCK at its
;; locked commit.  Run with: guix repl -- scripts/guix-pinned.scm LOCK

(use-modules (guix channels)
             (guix describe)
             (ice-9 match)
             (srfi srfi-1))

(define (channel-commit-pair channel)
  (cons (channel-name channel)
        (channel-commit channel)))

(define (channel-commits channels)
  (map channel-commit-pair channels))

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
