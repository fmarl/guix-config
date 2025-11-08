(use-package circe
  :ensure t
  :config
  (setq circe-default-realname "Florian M.L."
	circe-default-nick "fmarl"
	circe-default-user "fmarl")
  (setq circe-network-options
	'(("Libera Chat"
           :tls t
           :channels ("#guix")
           ))))
