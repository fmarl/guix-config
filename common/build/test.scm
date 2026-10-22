;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common build test)
  #:use-module (gnu build marionette)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:export (guest-start
            guest-file
            guest-file-exists?
            guest-output
            mounted-with?
            lan-tcp-ports
            sysctl-mismatches))

(define (guest-start marionette service)
  (marionette-eval `(begin
                      (use-modules (gnu services herd))
                      (start-service ',service))
                   marionette))

(define (guest-file marionette file)
  (marionette-eval `(begin
                      (use-modules (ice-9 textual-ports))
                      (call-with-input-file ,file get-string-all))
                   marionette))

(define (guest-file-exists? marionette file)
  (marionette-eval `(file-exists? ,file) marionette))

(define (guest-output marionette program . arguments)
  (marionette-eval `(begin
                      (use-modules (ice-9 popen)
                                   (ice-9 textual-ports))
                      (let* ((port (open-pipe* OPEN_READ ,program ,@arguments))
                             (output (get-string-all port)))
                        (close-pipe port)
                        output))
                   marionette))

(define (mount-options marionette mount-point)
  (or (any (lambda (line)
             (match (string-tokenize line)
               ((_ point _ options . _)
                (and (string=? point mount-point)
                     (string-split options #\,)))
               (_ #f)))
           (string-split (guest-file marionette "/proc/mounts") #\newline))
      '()))

(define (mounted-with? marionette mount-point . options)
  (lset<= string=? options (mount-options marionette mount-point)))

(define (lan-tcp-ports ruleset subnet)
  (let ((prefix (string-append "ip saddr " subnet " tcp dport ")))
    (sort (append-map (lambda (line)
                        (let ((line (string-trim-both line)))
                          (if (string-prefix? prefix line)
                              (map string->number
                                   (string-tokenize
                                    (string-drop line (string-length prefix))
                                    char-set:digit))
                              '())))
                      (string-split ruleset #\newline))
          <)))

(define (sysctl-file key)
  (string-append "/proc/sys/"
                 (string-map (lambda (c)
                               (if (char=? c #\.) #\/ c))
                             (string-trim key #\-))))

(define (sysctl-mismatches marionette settings)
  (filter-map
   (match-lambda
     ((key . expected)
      (let ((file (sysctl-file key)))
        (and (or (not (string-prefix? "-" key))
                 (guest-file-exists? marionette file))
             (let ((actual (string-join
                            (string-tokenize (guest-file marionette file))
                            " ")))
               (and (not (string=? actual expected))
                    (list key expected actual)))))))
   settings))
