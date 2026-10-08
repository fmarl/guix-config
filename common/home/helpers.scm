;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common home helpers)
  #:use-module (guix gexp)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:use-module (guix packages)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:export (ini-file
            toml-file
            css-file
            key-value-file
            shell-script
            home-packages
            kdl-file
            tagged-entries))

(define (value->string value)
  (match value
    (#t "true")
    (#f "false")
    ((? number?) (number->string value))
    ((? string?) value)
    ((? symbol?) (symbol->string value))))

(define (quoted str)
  (string-append "\""
                 (string-concatenate
                  (map (lambda (c)
                         (if (memv c '(#\" #\\))
                             (string #\\ c)
                             (string c)))
                       (string->list str)))
                 "\""))

(define (ini-value value)
  (let ((str (value->string value)))
    (if (string-any (lambda (c) (memv c '(#\; #\# #\" #\\))) str)
        (quoted str)
        str)))

(define (sections-file name sections format-value)
  "Return a file of [SECTION] headers followed by KEY = VALUE lines, with
VALUE serialized by FORMAT-VALUE."
  (define (entry->string entry)
    (match entry
      ((key . value)
       (string-append key " = " (format-value value) "\n"))))

  (define (section->string section)
    (match section
      ((header . entries)
       (string-append "[" header "]\n"
                      (string-concatenate (map entry->string entries))))))

  (plain-file name (string-join (map section->string sections) "\n")))

(define (ini-file name sections)
  "SECTIONS is a list of (SECTION (KEY . VALUE) ...), as used by git."
  (sections-file name sections ini-value))

(define (toml-value value)
  (match value
    ((? string?) (string-append "\"" value "\""))
    ((? vector?) (string-append "["
                                (string-join (map toml-value (vector->list value))
                                             ", ")
                                "]"))
    (_ (value->string value))))

(define (toml-file name tables)
  "TABLES is a list of (TABLE (KEY . VALUE) ...); strings are quoted and
vectors become arrays."
  (sections-file name tables toml-value))

(define (css-file name rules)
  "RULES is a list of ((SELECTOR ...) (PROPERTY . VALUE) ...)."
  (define (rule->string rule)
    (match rule
      ((selectors . declarations)
       (string-append (string-join selectors ",\n") " {\n"
                      (string-concatenate
                       (map (match-lambda
                              ((property . value)
                               (string-append "  " property ": " value ";\n")))
                            declarations))
                      "}\n"))))

  (plain-file name (string-join (map rule->string rules) "\n")))

(define (key-value-file name entries)
  "ENTRIES is a list of (KEY . VALUE); #t writes just KEY, as gpg.conf expects."
  (plain-file name
              (string-concatenate
               (map (match-lambda
                      ((key . #t) (string-append key "\n"))
                      ((key . value)
                       (string-append key " " (value->string value) "\n")))
                    entries))))

(define (shell-script name . text)
  "Return an executable /bin/sh script; TEXT may contain file-like objects."
  (computed-file name
                 #~(begin
                     (copy-file #$(apply mixed-text-file name "#!/bin/sh\n" text)
                                #$output)
                     (chmod #$output #o555))))

(define (home-packages . packages)
  "Return a service adding PACKAGES to the home profile."
  (simple-service (string->symbol
                   (string-append (package-name (car packages)) "-packages"))
                  home-profile-service-type
                  packages))

(define (kdl-value value)
  (match value
    ((? string?) (list (quoted value)))
    ((or #t #f (? number?)) (list (value->string value)))
    (_ (list "\"" value "\""))))

(define (kdl-name name)
  (if (symbol? name) (symbol->string name) name))

(define (kdl-arguments items)
  (match items
    (() '())
    (((? keyword? key) value . rest)
     `(" " ,(symbol->string (keyword->symbol key)) "=" ,@(kdl-value value)
       ,@(kdl-arguments rest)))
    (((? pair?) . rest)
     (kdl-arguments rest))
    ((value . rest)
     `(" " ,@(kdl-value value) ,@(kdl-arguments rest)))))

(define (kdl-nodes nodes depth)
  (define indent (make-string (* 4 depth) #\space))

  (append-map (match-lambda
                ((name . items)
                 (let ((children (filter pair? items)))
                   `(,indent ,(kdl-name name) ,@(kdl-arguments items)
                     ,@(if (null? children)
                           '("\n")
                           `(" {\n" ,@(kdl-nodes children (+ depth 1))
                             ,indent "}\n"))))))
              nodes))

(define (kdl-file name nodes)
  "NODES is a list of (NAME ITEM ...), where an ITEM is an argument, a
#:KEY VALUE property or a child node; values may be file-like."
  (apply mixed-text-file name (kdl-nodes nodes 0)))

(define (tagged-entries entries tag)
  "Return the payloads of the (TAG . PAYLOAD) ENTRIES tagged TAG, in order."
  (filter-map (match-lambda
                ((entry-tag . payload)
                 (and (eq? entry-tag tag) payload)))
              entries))
