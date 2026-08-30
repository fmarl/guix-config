;;; SPDX-License-Identifier: GPL-3.0-or-later
;;; Copyright © 2025, 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

(define-module (common home niri)
  #:use-module (guix gexp)
  #:use-module (guix records)
  #:use-module (srfi srfi-1)
  #:use-module (gnu services)
  #:use-module (gnu packages gnome)
  #:use-module (gnu packages window-management)
  #:use-module (gnu packages xorg)
  #:use-module (gnu home services)
  #:use-module (common home helpers)
  #:use-module (common home theme)
  #:use-module (common themes)
  #:export (home-niri-service-type
            niri-spawn-at-startup
            niri-bind
            niri-spawn
            niri-services))

(define (niri-spawn program . arguments)
  "Return the spawn action for PROGRAM, a string or file-like."
  `(spawn ,program ,@arguments))

(define (niri-spawn-at-startup program . arguments)
  `(startup . (spawn-at-startup ,program ,@arguments)))

(define* (niri-bind key action #:key title allow-when-locked?)
  "Bind KEY to ACTION, a node such as (close-window) or one returned by
niri-spawn."
  `(bind . (,key
            ,@(if title `(#:hotkey-overlay-title ,title) '())
            ,@(if allow-when-locked? '(#:allow-when-locked #t) '())
            ,action)))

(define (niri-settings theme)
  `((prefer-no-csd)
    (hotkey-overlay (skip-at-startup))
    (xwayland-satellite
     (path ,(file-append xwayland-satellite "/bin/xwayland-satellite")))
    (cursor (xcursor-theme ,%cursor-theme)
            (xcursor-size 24))
    (input (keyboard (xkb (layout "us")
                          (variant "altgr-intl")))
           (touchpad (tap)
                     (click-method "button-areas"))
           (trackball (off))
           (tablet (off))
           (touch (off))
           (mod-key "Super")
           (mod-key-nested "Alt"))
    (layout (gaps 10)
            (background-color ,(color theme 'bg_0))
            (center-focused-column "never")
            (preset-column-widths (proportion 0.33333)
                                  (proportion 0.5)
                                  (proportion 0.66667))
            (default-column-width (proportion 0.5))
            (focus-ring (width 2)
                        (active-color ,(color theme 'br_blue))
                        (inactive-color ,(color theme 'border)))
            (border (off))
            (shadow (softness 30)
                    (spread 5)
                    (offset #:x 0 #:y 5)
                    (color "#0007")))
    (overview (backdrop-color ,(color theme 'bg_0)))
    (screenshot-path
     "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png")
    (window-rule (match #:app-id "librewolf$" #:title "^Picture-in-Picture$")
                 (open-floating #t))
    (window-rule (match #:app-id "(?i)signal")
                 (block-out-from "screencast"))
    (layer-rule (match #:namespace "^notifications$")
                (block-out-from "screencast"))
    (layer-rule (match #:namespace "^waybar$")
                (block-out-from "screencast"))))

(define portals-conf
  (plain-file "niri-portals.conf"
              "[preferred]
default=gnome;gtk;
org.freedesktop.impl.portal.Access=gtk;
org.freedesktop.impl.portal.FileChooser=gtk;
org.freedesktop.impl.portal.Notification=gtk;
"))

(define %binds
  `((Mod+Shift+Slash (show-hotkey-overlay))
    (Mod+O #:repeat #f (toggle-overview))
    (Mod+Shift+C #:repeat #f (close-window))

    (Mod+Left (focus-column-left))
    (Mod+H (focus-column-left))
    (Mod+Down (focus-window-down))
    (Mod+J (focus-window-down))
    (Mod+Up (focus-window-up))
    (Mod+K (focus-window-up))
    (Mod+Right (focus-column-right))
    (Mod+L (focus-column-right))

    (Mod+Ctrl+Left (move-column-left))
    (Mod+Ctrl+H (move-column-left))
    (Mod+Ctrl+Down (move-window-down))
    (Mod+Ctrl+J (move-window-down))
    (Mod+Ctrl+Up (move-window-up))
    (Mod+Ctrl+K (move-window-up))
    (Mod+Ctrl+Right (move-column-right))
    (Mod+Ctrl+L (move-column-right))

    (Mod+Shift+Left (focus-monitor-left))
    (Mod+Shift+H (focus-monitor-left))
    (Mod+Shift+Down (focus-monitor-down))
    (Mod+Shift+J (focus-monitor-down))
    (Mod+Shift+Up (focus-monitor-up))
    (Mod+Shift+K (focus-monitor-up))
    (Mod+Shift+Right (focus-monitor-right))
    (Mod+Shift+L (focus-monitor-right))

    (Mod+Shift+Ctrl+Left (move-column-to-monitor-left))
    (Mod+Shift+Ctrl+H (move-column-to-monitor-left))
    (Mod+Shift+Ctrl+Down (move-column-to-monitor-down))
    (Mod+Shift+Ctrl+J (move-column-to-monitor-down))
    (Mod+Shift+Ctrl+Up (move-column-to-monitor-up))
    (Mod+Shift+Ctrl+K (move-column-to-monitor-up))
    (Mod+Shift+Ctrl+Right (move-column-to-monitor-right))
    (Mod+Shift+Ctrl+L (move-column-to-monitor-right))

    (Mod+Home (focus-column-first))
    (Mod+End (focus-column-last))
    (Mod+Ctrl+Home (move-column-to-first))
    (Mod+Ctrl+End (move-column-to-last))

    (Mod+Page_Down (focus-workspace-down))
    (Mod+U (focus-workspace-down))
    (Mod+Page_Up (focus-workspace-up))
    (Mod+I (focus-workspace-up))
    (Mod+Ctrl+Page_Down (move-column-to-workspace-down))
    (Mod+Ctrl+U (move-column-to-workspace-down))
    (Mod+Ctrl+Page_Up (move-column-to-workspace-up))
    (Mod+Ctrl+I (move-column-to-workspace-up))
    (Mod+Shift+Page_Down (move-workspace-down))
    (Mod+Shift+U (move-workspace-down))
    (Mod+Shift+Page_Up (move-workspace-up))
    (Mod+Shift+I (move-workspace-up))

    (Mod+WheelScrollDown #:cooldown-ms 150 (focus-workspace-down))
    (Mod+WheelScrollUp #:cooldown-ms 150 (focus-workspace-up))
    (Mod+Ctrl+WheelScrollDown #:cooldown-ms 150 (move-column-to-workspace-down))
    (Mod+Ctrl+WheelScrollUp #:cooldown-ms 150 (move-column-to-workspace-up))
    (Mod+WheelScrollRight (focus-column-right))
    (Mod+WheelScrollLeft (focus-column-left))
    (Mod+Ctrl+WheelScrollRight (move-column-right))
    (Mod+Ctrl+WheelScrollLeft (move-column-left))
    (Mod+Shift+WheelScrollDown (focus-column-right))
    (Mod+Shift+WheelScrollUp (focus-column-left))
    (Mod+Ctrl+Shift+WheelScrollDown (move-column-right))
    (Mod+Ctrl+Shift+WheelScrollUp (move-column-left))

    (Mod+BracketLeft (consume-or-expel-window-left))
    (Mod+BracketRight (consume-or-expel-window-right))
    (Mod+Comma (consume-window-into-column))
    (Mod+Period (expel-window-from-column))

    (Mod+R (switch-preset-column-width))
    (Mod+Shift+R (switch-preset-window-height))
    (Mod+Ctrl+R (reset-window-height))
    (Mod+F (maximize-column))
    (Mod+Shift+F (fullscreen-window))
    (Mod+Ctrl+F (expand-column-to-available-width))
    (Mod+C (center-column))
    (Mod+Ctrl+C (center-visible-columns))
    (Mod+Minus (set-column-width "-10%"))
    (Mod+Equal (set-column-width "+10%"))
    (Mod+Shift+Minus (set-window-height "-10%"))
    (Mod+Shift+Equal (set-window-height "+10%"))

    (Mod+V (toggle-window-floating))
    (Mod+Shift+V (switch-focus-between-floating-and-tiling))
    (Mod+W (toggle-column-tabbed-display))

    (Print (screenshot))
    (Ctrl+Print (screenshot-screen))
    (Alt+Print (screenshot-window))

    (Mod+Escape #:allow-inhibiting #f (toggle-keyboard-shortcuts-inhibit))
    (Mod+Shift+E (quit))
    (Ctrl+Alt+Delete (quit))
    (Mod+Shift+P (power-off-monitors))

    ,@(append-map (lambda (index)
                    (let ((n (number->string index)))
                      `((,(string-append "Mod+" n) (focus-workspace ,index))
                        (,(string-append "Mod+Ctrl+" n)
                         (move-column-to-workspace ,index)))))
                  (iota 9 1))))

(define-record-type* <home-niri-configuration>
  home-niri-configuration make-home-niri-configuration
  home-niri-configuration?
  (theme   home-niri-configuration-theme)
  (entries home-niri-configuration-entries (default '())))

(define (niri-config-file config)
  (define entries (home-niri-configuration-entries config))

  (let ((text (kdl-file "config.kdl"
                        (append (niri-settings
                                 (home-niri-configuration-theme config))
                                (tagged-entries entries 'startup)
                                `((binds ,@(tagged-entries entries 'bind)))))))
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
                        (lambda (config)
                          `(("niri/config.kdl" ,(niri-config-file config)))))))
                (compose concatenate)
                (extend (lambda (config entries)
                          (home-niri-configuration
                           (inherit config)
                           (entries (append (home-niri-configuration-entries
                                             config)
                                            entries)))))
                (description "Generate the niri configuration from the startup
commands and key bindings that other services contribute through
niri-spawn-at-startup and niri-bind.")))

(define (niri-services theme)
  (list (home-packages xwayland-satellite xdg-desktop-portal-gnome)
        (simple-service 'niri-portals
                        home-xdg-configuration-files-service-type
                        `(("xdg-desktop-portal/niri-portals.conf" ,portals-conf)))
        (service home-niri-service-type
                 (home-niri-configuration
                  (theme theme)
                  (entries (map (lambda (node) (cons 'bind node)) %binds))))))
