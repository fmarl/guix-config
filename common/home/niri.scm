(define-module (common home niri)
  #:use-module (guix gexp)
  #:use-module (gnu services)
  #:use-module (gnu packages)
  #:use-module (gnu packages emacs)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages terminals)
  #:use-module (gnu packages window-management)
  #:use-module (gnu packages xorg)
  #:use-module (gnu packages zig-xyz)
  #:use-module (gnu home services)
  #:use-module (common home helpers)
  #:use-module (common home bemenu)
  #:use-module (common home colors)
  #:use-module (common home swayidle)
  #:use-module (common home theme)
  #:export (%niri-services))

(define wpctl (file-append wireplumber "/bin/wpctl"))
(define brightnessctl* (file-append brightnessctl "/bin/brightnessctl"))

(define niri-config-text
  (mixed-text-file "config.kdl" "
prefer-no-csd

xwayland-satellite {
    path \"" xwayland-satellite "/bin/xwayland-satellite\"
}


cursor {
    xcursor-theme \"" %cursor-theme "\"
    xcursor-size 24
}

input {
  keyboard {
      xkb {
          layout \"us\"
          variant \"altgr-intl\"
      }
  }

  touchpad {
      tap;
      click-method \"button-areas\";
  }

  trackpoint {
      off
  }

  trackball {
      off
  }

  tablet {
      off
  }

  touch {
      off
  }

  mod-key \"Super\"
  mod-key-nested \"Alt\"
}

layout {
    gaps 10
    background-color \"" (color 'bg_0) "\"
    center-focused-column \"never\"

    preset-column-widths {
        proportion 0.33333
        proportion 0.5
        proportion 0.66667
    }

    default-column-width { proportion 0.5; }

    focus-ring {
        width 2

        active-color \"" (color 'br_blue) "\"

        inactive-color \"" (color 'border) "\"
    }

    border { off; }

    shadow {
        softness 30

        spread 5

        offset x=0 y=5

        color \"#0007\"
    }
}

screenshot-path \"~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png\"

window-rule {
    match app-id=r#\"librewolf$\"# title=\"^Picture-in-Picture$\"
    open-floating true
}

spawn-at-startup \"" waybar "/bin/waybar\"
spawn-at-startup \"" mako "/bin/mako\"
spawn-at-startup \"" swayidle "/bin/swayidle\" \"-w\"
spawn-sh-at-startup \"" swaybg "/bin/swaybg -i $HOME/Pictures/wallpaper.svg\"

binds {
    Mod+Shift+Slash { show-hotkey-overlay; }

    Mod+Shift+Return hotkey-overlay-title=\"Open alacritty\" { spawn \"" alacritty "/bin/alacritty\"; }
    Mod+P hotkey-overlay-title=\"Run bemenu\" { spawn \"" bemenu-run "\"; }
    Super+Alt+L hotkey-overlay-title=\"Lock the Screen\" { spawn \"" lock-program "\"; }
    Mod+Shift+D hotkey-overlay-title=\"Start dirvish\" { spawn \"" emacs-next-pgtk "/bin/emacsclient\" \"-s\" \"emacs-daemon\" \"-c\" \"-n\" \"-e\" \"(dirvish-dwim)\"; }

    XF86AudioRaiseVolume allow-when-locked=true { spawn \"" wpctl "\" \"set-volume\" \"@DEFAULT_AUDIO_SINK@\" \"0.1+\"; }
    XF86AudioLowerVolume allow-when-locked=true { spawn \"" wpctl "\" \"set-volume\" \"@DEFAULT_AUDIO_SINK@\" \"0.1-\"; }
    XF86AudioMute        allow-when-locked=true { spawn \"" wpctl "\" \"set-mute\" \"@DEFAULT_AUDIO_SINK@\" \"toggle\"; }
    XF86AudioMicMute     allow-when-locked=true { spawn \"" wpctl "\" \"set-mute\" \"@DEFAULT_AUDIO_SOURCE@\" \"toggle\"; }

    XF86MonBrightnessUp allow-when-locked=true { spawn \"" brightnessctl* "\" \"--class=backlight\" \"set\" \"+10%\"; }
    XF86MonBrightnessDown allow-when-locked=true { spawn \"" brightnessctl* "\" \"--class=backlight\" \"set\" \"10%-\"; }

    Mod+O repeat=false { toggle-overview; }

    Mod+Shift+C repeat=false { close-window; }

    Mod+Left  { focus-column-left; }
    Mod+Down  { focus-window-down; }
    Mod+Up    { focus-window-up; }
    Mod+Right { focus-column-right; }
    Mod+H     { focus-column-left; }
    Mod+J     { focus-window-down; }
    Mod+K     { focus-window-up; }
    Mod+L     { focus-column-right; }

    Mod+Ctrl+Left  { move-column-left; }
    Mod+Ctrl+Down  { move-window-down; }
    Mod+Ctrl+Up    { move-window-up; }
    Mod+Ctrl+Right { move-column-right; }
    Mod+Ctrl+H     { move-column-left; }
    Mod+Ctrl+J     { move-window-down; }
    Mod+Ctrl+K     { move-window-up; }
    Mod+Ctrl+L     { move-column-right; }

    Mod+Home { focus-column-first; }
    Mod+End  { focus-column-last; }
    Mod+Ctrl+Home { move-column-to-first; }
    Mod+Ctrl+End  { move-column-to-last; }

    Mod+Shift+Left  { focus-monitor-left; }
    Mod+Shift+Down  { focus-monitor-down; }
    Mod+Shift+Up    { focus-monitor-up; }
    Mod+Shift+Right { focus-monitor-right; }
    Mod+Shift+H     { focus-monitor-left; }
    Mod+Shift+J     { focus-monitor-down; }
    Mod+Shift+K     { focus-monitor-up; }
    Mod+Shift+L     { focus-monitor-right; }

    Mod+Shift+Ctrl+Left  { move-column-to-monitor-left; }
    Mod+Shift+Ctrl+Down  { move-column-to-monitor-down; }
    Mod+Shift+Ctrl+Up    { move-column-to-monitor-up; }
    Mod+Shift+Ctrl+Right { move-column-to-monitor-right; }
    Mod+Shift+Ctrl+H     { move-column-to-monitor-left; }
    Mod+Shift+Ctrl+J     { move-column-to-monitor-down; }
    Mod+Shift+Ctrl+K     { move-column-to-monitor-up; }
    Mod+Shift+Ctrl+L     { move-column-to-monitor-right; }

    Mod+Page_Down      { focus-workspace-down; }
    Mod+Page_Up        { focus-workspace-up; }
    Mod+U              { focus-workspace-down; }
    Mod+I              { focus-workspace-up; }
    Mod+Ctrl+Page_Down { move-column-to-workspace-down; }
    Mod+Ctrl+Page_Up   { move-column-to-workspace-up; }
    Mod+Ctrl+U         { move-column-to-workspace-down; }
    Mod+Ctrl+I         { move-column-to-workspace-up; }

    Mod+Shift+Page_Down { move-workspace-down; }
    Mod+Shift+Page_Up   { move-workspace-up; }
    Mod+Shift+U         { move-workspace-down; }
    Mod+Shift+I         { move-workspace-up; }

    Mod+WheelScrollDown      cooldown-ms=150 { focus-workspace-down; }
    Mod+WheelScrollUp        cooldown-ms=150 { focus-workspace-up; }
    Mod+Ctrl+WheelScrollDown cooldown-ms=150 { move-column-to-workspace-down; }
    Mod+Ctrl+WheelScrollUp   cooldown-ms=150 { move-column-to-workspace-up; }

    Mod+WheelScrollRight      { focus-column-right; }
    Mod+WheelScrollLeft       { focus-column-left; }
    Mod+Ctrl+WheelScrollRight { move-column-right; }
    Mod+Ctrl+WheelScrollLeft  { move-column-left; }

    Mod+Shift+WheelScrollDown      { focus-column-right; }
    Mod+Shift+WheelScrollUp        { focus-column-left; }
    Mod+Ctrl+Shift+WheelScrollDown { move-column-right; }
    Mod+Ctrl+Shift+WheelScrollUp   { move-column-left; }

    Mod+1 { focus-workspace 1; }
    Mod+2 { focus-workspace 2; }
    Mod+3 { focus-workspace 3; }
    Mod+4 { focus-workspace 4; }
    Mod+5 { focus-workspace 5; }
    Mod+6 { focus-workspace 6; }
    Mod+7 { focus-workspace 7; }
    Mod+8 { focus-workspace 8; }
    Mod+9 { focus-workspace 9; }
    Mod+Ctrl+1 { move-column-to-workspace 1; }
    Mod+Ctrl+2 { move-column-to-workspace 2; }
    Mod+Ctrl+3 { move-column-to-workspace 3; }
    Mod+Ctrl+4 { move-column-to-workspace 4; }
    Mod+Ctrl+5 { move-column-to-workspace 5; }
    Mod+Ctrl+6 { move-column-to-workspace 6; }
    Mod+Ctrl+7 { move-column-to-workspace 7; }
    Mod+Ctrl+8 { move-column-to-workspace 8; }
    Mod+Ctrl+9 { move-column-to-workspace 9; }

    Mod+BracketLeft  { consume-or-expel-window-left; }
    Mod+BracketRight { consume-or-expel-window-right; }

    Mod+Comma  { consume-window-into-column; }

    Mod+Period { expel-window-from-column; }

    Mod+R { switch-preset-column-width; }
    Mod+Shift+R { switch-preset-window-height; }
    Mod+Ctrl+R { reset-window-height; }
    Mod+F { maximize-column; }
    Mod+Shift+F { fullscreen-window; }

    Mod+Ctrl+F { expand-column-to-available-width; }

    Mod+C { center-column; }

    Mod+Ctrl+C { center-visible-columns; }

    Mod+Minus { set-column-width \"-10%\"; }
    Mod+Equal { set-column-width \"+10%\"; }

    Mod+Shift+Minus { set-window-height \"-10%\"; }
    Mod+Shift+Equal { set-window-height \"+10%\"; }

    Mod+V       { toggle-window-floating; }
    Mod+Shift+V { switch-focus-between-floating-and-tiling; }

    Mod+W { toggle-column-tabbed-display; }

    Print { screenshot; }
    Ctrl+Print { screenshot-screen; }
    Alt+Print { screenshot-window; }

    Mod+Escape allow-inhibiting=false { toggle-keyboard-shortcuts-inhibit; }

    Mod+Shift+E { quit; }
    Ctrl+Alt+Delete { quit; }

    Mod+Shift+P { power-off-monitors; }
}
"))

(define niri-config
  (computed-file "niri-config.kdl"
		 #~(begin
		     (unless (zero? (system* #$(file-append niri "/bin/niri")
					     "validate" "-c" #$niri-config-text))
		       (error "invalid niri configuration"))
		     (copy-file #$niri-config-text #$output))))

(define %niri-services
  (list (home-packages "xwayland-satellite"
		       "wl-clipboard"
		       "xdg-desktop-portal"
		       "xdg-desktop-portal-gnome"
		       "xdg-desktop-portal-gtk"
		       "imv"
		       "zathura"
		       "zathura-pdf-mupdf"
		       "mpv")
	(simple-service 'niri-config
			home-xdg-configuration-files-service-type
			`(("niri/config.kdl" ,niri-config)))))
