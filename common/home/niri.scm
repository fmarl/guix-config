(define-module (common home niri)
  #:use-module (guix gexp)
  #:use-module (ice-9 match)
  #:use-module (srfi srfi-1)
  #:use-module (gnu services)
  #:use-module (gnu packages)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages terminals)
  #:use-module (gnu packages window-management)
  #:use-module (gnu packages xorg)
  #:use-module (gnu home services)
  #:use-module (common home helpers)
  #:use-module (common home bemenu)
  #:use-module (common home colors)
  #:use-module (common home emacs)
  #:use-module (common home theme)
  #:export (home-niri-service-type
            niri-spawn-at-startup
            niri-spawn-sh-at-startup
            niri-bind
            niri-spawn
            niri-services))

(define (kdl-arguments arguments)
  (append-map (lambda (argument)
                (list " \"" argument "\""))
              arguments))

(define (niri-spawn program . arguments)
  "Return the spawn action for PROGRAM, a string or file-like."
  (cons "spawn" (kdl-arguments (cons program arguments))))

(define (niri-spawn-at-startup program . arguments)
  `(startup "spawn-at-startup" ,@(kdl-arguments (cons program arguments)) "\n"))

(define (niri-spawn-sh-at-startup . command)
  `(startup "spawn-sh-at-startup \"" ,@command "\"\n"))

(define* (niri-bind key action #:key title)
  "Bind KEY (with its properties) to ACTION, a string or a list as returned by
niri-spawn."
  `(bind "    " ,key
         ,@(if title
               (list " hotkey-overlay-title=\"" title "\"")
               '())
         " { " ,@(if (string? action) (list action) action) "; }\n"))

(define (bind-keys modifiers keys action)
  (map (lambda (key)
         (niri-bind (string-append modifiers "+" key) action))
       keys))

(define niri-settings
  (list "prefer-no-csd

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
        tap
        click-method \"button-areas\"
    }

    trackpoint { off; }
    trackball { off; }
    tablet { off; }
    touch { off; }

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
"))

(define directional-binds
  (append-map
   (match-lambda
     ((direction target . keys)
      (append
       (bind-keys "Mod" keys (string-append "focus-" target "-" direction))
       (bind-keys "Mod+Ctrl" keys (string-append "move-" target "-" direction))
       (bind-keys "Mod+Shift" keys (string-append "focus-monitor-" direction))
       (bind-keys "Mod+Shift+Ctrl" keys
                  (string-append "move-column-to-monitor-" direction)))))
   '(("left" "column" "Left" "H")
     ("down" "window" "Down" "J")
     ("up" "window" "Up" "K")
     ("right" "column" "Right" "L"))))

(define workspace-binds
  (append
   (append-map
    (match-lambda
      ((direction . keys)
       (append
        (bind-keys "Mod" keys (string-append "focus-workspace-" direction))
        (bind-keys "Mod+Ctrl" keys
                   (string-append "move-column-to-workspace-" direction))
        (bind-keys "Mod+Shift" keys (string-append "move-workspace-" direction)))))
    '(("down" "Page_Down" "U")
      ("up" "Page_Up" "I")))
   (append-map (lambda (index)
                 (let ((n (number->string index)))
                   (list (niri-bind (string-append "Mod+" n)
                                    (string-append "focus-workspace " n))
                         (niri-bind (string-append "Mod+Ctrl+" n)
                                    (string-append "move-column-to-workspace " n)))))
               (iota 9 1))))

(define (media-binds bindings)
  (map (match-lambda
         ((key program . arguments)
          (niri-bind (string-append key " allow-when-locked=true")
                     (apply niri-spawn program arguments))))
       bindings))

(define audio-binds
  (let ((wpctl (file-append wireplumber "/bin/wpctl")))
    (media-binds
     `(("XF86AudioRaiseVolume" ,wpctl "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1+")
       ("XF86AudioLowerVolume" ,wpctl "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1-")
       ("XF86AudioMute" ,wpctl "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle")
       ("XF86AudioMicMute" ,wpctl "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle")))))

(define brightness-binds
  (let ((brightnessctl (file-append brightnessctl "/bin/brightnessctl")))
    (media-binds
     `(("XF86MonBrightnessUp" ,brightnessctl "--class=backlight" "set" "+10%")
       ("XF86MonBrightnessDown" ,brightnessctl "--class=backlight" "set" "10%-")))))

(define action-binds
  (map (match-lambda
         ((key action) (niri-bind key action)))
       '(("Mod+Shift+Slash" "show-hotkey-overlay")
         ("Mod+O repeat=false" "toggle-overview")
         ("Mod+Shift+C repeat=false" "close-window")

         ("Mod+Home" "focus-column-first")
         ("Mod+End" "focus-column-last")
         ("Mod+Ctrl+Home" "move-column-to-first")
         ("Mod+Ctrl+End" "move-column-to-last")

         ("Mod+WheelScrollDown cooldown-ms=150" "focus-workspace-down")
         ("Mod+WheelScrollUp cooldown-ms=150" "focus-workspace-up")
         ("Mod+Ctrl+WheelScrollDown cooldown-ms=150" "move-column-to-workspace-down")
         ("Mod+Ctrl+WheelScrollUp cooldown-ms=150" "move-column-to-workspace-up")
         ("Mod+WheelScrollRight" "focus-column-right")
         ("Mod+WheelScrollLeft" "focus-column-left")
         ("Mod+Ctrl+WheelScrollRight" "move-column-right")
         ("Mod+Ctrl+WheelScrollLeft" "move-column-left")
         ("Mod+Shift+WheelScrollDown" "focus-column-right")
         ("Mod+Shift+WheelScrollUp" "focus-column-left")
         ("Mod+Ctrl+Shift+WheelScrollDown" "move-column-right")
         ("Mod+Ctrl+Shift+WheelScrollUp" "move-column-left")

         ("Mod+BracketLeft" "consume-or-expel-window-left")
         ("Mod+BracketRight" "consume-or-expel-window-right")
         ("Mod+Comma" "consume-window-into-column")
         ("Mod+Period" "expel-window-from-column")

         ("Mod+R" "switch-preset-column-width")
         ("Mod+Shift+R" "switch-preset-window-height")
         ("Mod+Ctrl+R" "reset-window-height")
         ("Mod+F" "maximize-column")
         ("Mod+Shift+F" "fullscreen-window")
         ("Mod+Ctrl+F" "expand-column-to-available-width")
         ("Mod+C" "center-column")
         ("Mod+Ctrl+C" "center-visible-columns")
         ("Mod+Minus" "set-column-width \"-10%\"")
         ("Mod+Equal" "set-column-width \"+10%\"")
         ("Mod+Shift+Minus" "set-window-height \"-10%\"")
         ("Mod+Shift+Equal" "set-window-height \"+10%\"")

         ("Mod+V" "toggle-window-floating")
         ("Mod+Shift+V" "switch-focus-between-floating-and-tiling")
         ("Mod+W" "toggle-column-tabbed-display")

         ("Print" "screenshot")
         ("Ctrl+Print" "screenshot-screen")
         ("Alt+Print" "screenshot-window")

         ("Mod+Escape allow-inhibiting=false" "toggle-keyboard-shortcuts-inhibit")
         ("Mod+Shift+E" "quit")
         ("Ctrl+Alt+Delete" "quit")
         ("Mod+Shift+P" "power-off-monitors"))))

(define launcher-binds
  (list (niri-bind "Mod+Shift+Return"
                   (niri-spawn (file-append alacritty "/bin/alacritty"))
                   #:title "Open alacritty")
        (niri-bind "Mod+P" (niri-spawn bemenu-run)
                   #:title "Run bemenu")
        (niri-bind "Mod+Shift+D"
                   (apply niri-spawn (emacsclient-command "-c" "-n" "-e"
                                                          "(dirvish-dwim)"))
                   #:title "Start dirvish")))

(define (niri-config-file entries)
  (define (section name)
    (append-map cdr (filter (lambda (entry) (eq? (car entry) name)) entries)))

  (let ((text (apply mixed-text-file "config.kdl"
                     (append niri-settings
                             '("\n")
                             (section 'startup)
                             '("\nbinds {\n")
                             (section 'bind)
                             '("}\n")))))
    (computed-file "niri-config.kdl"
                   #~(begin
                       (unless (zero? (system* #$(file-append niri "/bin/niri")
                                               "validate" "-c" #$text))
                         (error "invalid niri configuration"))
                       (copy-file #$text #$output)))))

(define home-niri-service-type
  (service-type (name 'home-niri)
                (extensions
                 (list (service-extension
                        home-xdg-configuration-files-service-type
                        (lambda (entries)
                          `(("niri/config.kdl" ,(niri-config-file entries)))))))
                (compose concatenate)
                (extend append)
                (default-value '())
                (description "Generate the niri configuration from the startup
commands and key bindings that other services contribute through
niri-spawn-at-startup and niri-bind.")))

(define* (niri-services #:key (audio? #t))
  (list (home-packages "xwayland-satellite"
                       "wl-clipboard"
                       "xdg-desktop-portal"
                       "xdg-desktop-portal-gnome"
                       "xdg-desktop-portal-gtk"
                       "imv-locked"
                       "zathura"
                       "zathura-pdf-mupdf"
                       "mpv")
        (service home-niri-service-type
                 (append (list (niri-spawn-sh-at-startup
                                swaybg "/bin/swaybg -i $HOME/Pictures/wallpaper.svg"))
                         launcher-binds
                         brightness-binds
                         (if audio? audio-binds '())
                         action-binds
                         directional-binds
                         workspace-binds))))
