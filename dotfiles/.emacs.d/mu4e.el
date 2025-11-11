(use-package mu4e
  :ensure nil
  :defer 5
  :config
  (setq mu4e-maildir "~/Maildir"
        mu4e-get-mail-command "mbsync -a"
        mu4e-update-interval 300
        mu4e-view-show-images t
        mu4e-view-show-addresses t
        mu4e-compose-format-flowed t
        mu4e-headers-auto-update t
        mu4e-headers-date-format "%Y-%m-%d %H:%M"
        mu4e-headers-fields '((:date . 20)
                              (:flags . 6)
                              (:from . 22)
                              (:subject)))

  ;; --- General data ---
  (setq user-full-name      "Florian Marrero Liestmann"
        user-mail-address   "f.m.liestmann@fx-ttr.de")

  ;; --- Sending via msmtp ---
  (setq message-send-mail-function 'message-send-mail-with-sendmail
        sendmail-program "/usr/bin/msmtp"
        mail-specify-envelope-from t
        mail-envelope-from 'header
        message-sendmail-f-is-evil t
        message-sendmail-extra-arguments '("--read-envelope-from"))

  ;; --- Default folder ---
  (setq mu4e-sent-folder   "/Sent"
        mu4e-drafts-folder "/Drafts"
        mu4e-trash-folder  "/Trash"
        mu4e-refile-folder "/Archive")

  ;; --- Signatur ---
  (setq mu4e-compose-signature "- Florian")

  (add-to-list 'mu4e-view-actions
               '("View in browser" . mu4e-action-view-in-browser) t)

  (setq mu4e-maildir-shortcuts
        '(("/INBOX"          . ?i)
          ("/linux-kernel"   . ?k)
          ("/linux-janitors" . ?j)
          ("/guix-devel"     . ?g)
          ("/Sent"           . ?s)
          ("/Archive"        . ?a)))

  (setq mu4e-bookmarks
        '(("maildir:/INBOX AND flag:unread" :name "Ungelesen" :key ?u)
          ("maildir:/linux-kernel AND flag:unread" :name "Kernel ML" :key ?K)
          ("maildir:/linux-janitors AND flag:unread" :name "Janitors ML" :key ?J)
          ("maildir:/guix-devel AND flag:unread" :name "Guix-devel ML" :key ?G)
          ("maildir:/linux-kernel OR maildir:/linux-janitors OR maildir:/guix-devel"
           :name "Alle Mailinglisten" :key ?M)))

  (setq mu4e-headers-include-related t))
