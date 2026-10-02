(define-module (common home helpers)
  #:use-module (guix gexp)
  #:use-module (ice-9 match)
  #:use-module (gnu packages)
  #:use-module (gnu services)
  #:use-module (gnu home services)
  #:export (ini-file
            toml-file
            key-value-file
            shell-script
            home-packages))

(define (value->string value)
  (match value
    (#t "true")
    (#f "false")
    ((? number?) (number->string value))
    ((? string?) value)
    ((? symbol?) (symbol->string value))))

(define (ini-value value)
  (let ((str (value->string value)))
    (if (string-any (lambda (c) (memv c '(#\; #\# #\" #\\))) str)
        (string-append "\""
                       (string-concatenate
                        (map (lambda (c)
                               (if (memv c '(#\" #\\))
                                   (string #\\ c)
                                   (string c)))
                             (string->list str)))
                       "\"")
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

(define (home-packages . specifications)
  "Return a service adding SPECIFICATIONS to the home profile."
  (simple-service (string->symbol (string-append (car specifications) "-packages"))
                  home-profile-service-type
                  (specifications->packages specifications)))
