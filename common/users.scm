(define-module (common users)
  #:use-module (gnu packages shells)
  #:use-module (gnu system accounts)
  #:use-module (guix gexp)
  #:use-module (guix records)
  #:export (%primary-user
            %users
            %user-accounts
            user-name
            user-full-name
            user-email
            user-gpg-key
            user-u2f-keys))

(define-record-type* <user> user make-user
  user?
  (name      user-name)
  (full-name user-full-name)
  (email     user-email)
  (gpg-key   user-gpg-key)
  (u2f-keys  user-u2f-keys (default #f)))

(define %users
  (list (user
         (name "marrero")
         (full-name "Florian Marrero Liestmann")
         (email "f.m.liestmann@fx-ttr.de")
         (gpg-key "D1912EEBC3FBEBB4")
         (u2f-keys "NYkhoS5+8SwGfd6s2+kNDB6lUHYOsEG73xRqaM0qYP4YHZSs7YzMdlMPqfhVlSF5yoiQiicHbxpWzHVwpwtkRA==,xdBNy40OgdldkNuoh42OrS6YwohCSSW4gjqX7NkKqqDxfS2qhws3XAGd3mJfaLUJ9tDwrM7LaPo0y+XDKljrDg==,es256,+presence"))))

(define %primary-user (car %users))

(define %user-groups
  '("wheel" "netdev" "audio" "video" "seat" "plugdev" "kvm"))

(define %user-accounts
  (map (lambda (user)
         (user-account
          (name (user-name user))
          (comment (user-full-name user))
          (group "users")
          (shell (file-append zsh "/bin/zsh"))
          (home-directory (string-append "/home/" (user-name user)))
          (supplementary-groups %user-groups)))
       %users))
