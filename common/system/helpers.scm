;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common system helpers)
  #:use-module (guix build-system copy)
  #:use-module (guix gexp)
  #:use-module (guix packages)
  #:use-module (gnu services)
  #:export (system-commands))

(define (command-package command)
  (let ((name (program-file-name command)))
    (package
      (name name)
      (version "0")
      (source
       command)
      (build-system copy-build-system)
      (arguments
       (list
        #:install-plan
        #~'((#$name
             "bin/"))))
      (home-page #f)
      (synopsis #f)
      (description #f)
      (license #f))))

(define (system-commands . commands)
  "Install the program-files COMMANDS in the system profile."
  (simple-service (string->symbol (string-append (program-file-name (car
                                                                     commands))
                                                 "-commands"))
                  profile-service-type
                  (map command-package commands)))
