(use-package mu4e
  :ensure nil
  :defer 10
  :config
  (setq mu4e-maildir "~/Maildir")

  ;; Ordnerstruktur
  (setq mu4e-sent-folder   "/Sent"
        mu4e-drafts-folder "/Drafts"
        mu4e-trash-folder  "/Trash"
        mu4e-refile-folder "/Archive")

  ;; Mail-Sync-Command (z. B. mbsync)
  (setq mu4e-get-mail-command "mbsync -a"
        mu4e-update-interval 300)  ; alle 5 Minuten

  ;; Anzeigen & Verhalten
  (setq mu4e-view-show-images t
        mu4e-view-show-addresses t
        mu4e-compose-format-flowed t
        mu4e-headers-auto-update t
        mu4e-headers-date-format "%Y-%m-%d %H:%M"
        mu4e-headers-fields '((:date . 20)
                              (:flags . 6)
                              (:from . 22)
                              (:subject)))

  ;; Standardabsender
  (setq user-full-name "Max Mustermann"
        user-mail-address "max@example.com")

  ;; SMTP-Versand via msmtp
  (setq message-send-mail-function 'message-send-mail-with-sendmail
        sendmail-program "/usr/bin/msmtp"
        message-sendmail-f-is-evil t
        message-sendmail-extra-arguments '("--read-envelope-from")
        mail-specify-envelope-from t
        mail-envelope-from 'header)

  ;; Signaturen (optional)
  (setq mu4e-compose-signature
        "Beste Grüße,\nMax Mustermann")

  ;; HTML-Mails in Browser öffnen
  (add-to-list 'mu4e-view-actions
               '("View in browser" . mu4e-action-view-in-browser) t)

  ;; Kontext-Unterstützung (mehrere Accounts)
  (setq mu4e-contexts
        (list
         (make-mu4e-context
          :name "Privat"
          :enter-func (lambda () (mu4e-message "Privat-Kontext"))
          :match-func (lambda (msg)
                        (when msg
                          (string-match-p "max@example.com"
                                          (mu4e-message-field msg :to))))
          :vars '((user-mail-address . "max@example.com")
                  (mu4e-sent-folder  . "/Sent")
                  (mu4e-drafts-folder . "/Drafts")
                  (smtpmail-smtp-server . "smtp.example.com")
                  (smtpmail-smtp-service . 587)))
         (make-mu4e-context
          :name "Arbeit"
          :enter-func (lambda () (mu4e-message "Arbeits-Kontext"))
          :match-func (lambda (msg)
                        (when msg
                          (string-match-p "max@firma.de"
                                          (mu4e-message-field msg :to))))
          :vars '((user-mail-address . "max@firma.de")
                  (mu4e-sent-folder  . "/Firma/Sent")
                  (mu4e-drafts-folder . "/Firma/Drafts")
                  (smtpmail-smtp-server . "smtp.firma.de")
                  (smtpmail-smtp-service . 587)))))

  (setq mu4e-context-policy 'pick-first
        mu4e-compose-context-policy 'ask))

;; ─────────────────────────────────────────────
;; Optional: Org-mode Integration
;; ─────────────────────────────────────────────
(use-package org-mu4e
  :after mu4e
  :config
  (setq org-mu4e-link-query-in-headers-mode nil))
