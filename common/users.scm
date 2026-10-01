(define-module (common users)
  #:use-module (gnu packages)
  #:use-module (gnu system accounts)
  #:use-module (guix gexp)
  #:export (%primary-user
            %users
            user-name
            user-full-name
            user-email
            user-gpg-key
            user-u2f-keys
            make-user-accounts))

(define %users
  '(("marrero"
     (full-name . "Florian Marrero Liestmann")
     (email . "f.m.liestmann@fx-ttr.de")
     (gpg-key . "D1912EEBC3FBEBB4")
     (u2f-keys . "NYkhoS5+8SwGfd6s2+kNDB6lUHYOsEG73xRqaM0qYP4YHZSs7YzMdlMPqfhVlSF5yoiQiicHbxpWzHVwpwtkRA==,xdBNy40OgdldkNuoh42OrS6YwohCSSW4gjqX7NkKqqDxfS2qhws3XAGd3mJfaLUJ9tDwrM7LaPo0y+XDKljrDg==,es256,+presence"))))

(define %primary-user (car %users))

(define (user-name user) (car user))
(define (user-attr user key) (assq-ref (cdr user) key))
(define (user-full-name user) (user-attr user 'full-name))
(define (user-email user) (user-attr user 'email))
(define (user-gpg-key user) (user-attr user 'gpg-key))
(define (user-u2f-keys user) (user-attr user 'u2f-keys))

(define %user-groups
  '("wheel" "netdev" "audio" "video" "seat" "plugdev"))

(define* (make-user-accounts #:key (extra-groups '()))
  (map (lambda (user)
         (user-account
          (name (user-name user))
          (comment (user-full-name user))
          (group "users")
          (shell (file-append (specification->package "zsh") "/bin/zsh"))
          (home-directory (string-append "/home/" (user-name user)))
          (supplementary-groups (append %user-groups extra-groups))))
       %users))
