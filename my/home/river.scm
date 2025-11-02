(define-module (my home river)
  #:use-module (guix gexp)
  #:use-module (gnu services)
  #:use-module (gnu packages)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages pulseaudio)
  #:use-module (gnu home services)
  #:export (
	    %river-services
	    %river-packages
))

(define %river-init
  (computed-file "init"
		 #~(begin
		     (call-with-output-file #$output
		       (lambda (port)
			 (display
			  (format #f "
#!/bin/sh

### App Launcher ###
riverctl map normal Super P spawn bemenu-run
riverctl map normal Super+Shift D spawn 'alacritty -e lf'
riverctl map normal Super+Shift Return spawn alacritty

### General WM Control ###
riverctl map normal Super+Shift C close
riverctl map normal Super Q exit

### Navigation ###
# Views
riverctl map normal Super J focus-view next
riverctl map normal Super K focus-view previous
riverctl map normal Super+Shift J swap next
riverctl map normal Super+Shift K swap previous

# Outputs
riverctl map normal Super Period focus-output next
riverctl map normal Super Comma focus-output previous
riverctl map normal Super+Shift Period send-to-output next
riverctl map normal Super+Shift Comma send-to-output previous

riverctl map normal Super Return zoom

riverctl map normal Super H send-layout-cmd rivertile 'main-ratio -0.05'
riverctl map normal Super L send-layout-cmd rivertile 'main-ratio +0.05'
riverctl map normal Super+Shift H send-layout-cmd rivertile 'main-count +1'
riverctl map normal Super+Shift L send-layout-cmd rivertile 'main-count -1'

riverctl map-pointer normal Super BTN_LEFT move-view
riverctl map-pointer normal Super BTN_RIGHT resize-view
riverctl map-pointer normal Super BTN_MIDDLE toggle-float

for i in $(seq 1 9); do
  tags=$((1 << ($i - 1)))

  # Super+[1-9] to focus tag [0-8]
  riverctl map normal Super $i set-focused-tags $tags

  # Super+Shift+[1-9] to tag focused view with tag [0-8]
  riverctl map normal Super+Shift $i set-view-tags $tags

  # Super+Control+[1-9] to toggle focus of tag [0-8]
  riverctl map normal Super+Control $i toggle-focused-tags $tags

  # Super+Shift+Control+[1-9] to toggle tag [0-8] of focused view
  riverctl map normal Super+Shift+Control $i toggle-view-tags $tags
done

### Tiling ###
riverctl default-layout rivertile
rivertile -view-padding 6 -outer-padding 6 &

### Rules ###
riverctl rule-add -app-id 'ghidra-Ghidra' float
riverctl rule-add -app-id 'burp-StartBurp' float
riverctl rule-add -app-id 'org.wireshark.Wireshark' float
riverctl rule-add -app-id 'Signal' float

### Keyboard Layout ###
riverctl keyboard-layout -variant altgr-intl us

### Touchpad ###
riverctl input pointer-1267-35-Elan_Touchpad tap enabled

### Brightness ###
riverctl map normal None XF86MonBrightnessUp   spawn '~a set +5%'
riverctl map normal None XF86MonBrightnessDown spawn '~a set 5%-'

### Volume ###
riverctl map normal None XF86AudioRaiseVolume  spawn '~a -i 5'
riverctl map normal None XF86AudioLowerVolume  spawn '~a -d 5'
riverctl map normal None XF86AudioMute         spawn '~a --toggle-mute'

waybar &
"
				  #$(file-append brightnessctl "/bin/brightnessctl")
				  #$(file-append brightnessctl "/bin/brightnessctl")
				  #$(file-append pamixer "/bin/pamixer")
				  #$(file-append pamixer "/bin/pamixer")
				  #$(file-append pamixer "/bin/pamixer"))
			  port)))
		     (chmod #$output #o700))))

(define %river-services
  (list (simple-service 'river-config
			home-files-service-type
			`((".config/river/init"
			   ,%river-init)))))


(define %river-packages
  (specifications->packages
   (list "river"
	 "bemenu"
	 "imv"
	 "zathura"
	 "mpv")))
