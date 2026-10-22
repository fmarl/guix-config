# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

notified="$XDG_RUNTIME_DIR/battery-alert"
mkdir -p "$notified"

while [ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; do
    for battery in /sys/class/power_supply/BAT*; do
        marker="$notified/${battery##*/}"
        capacity=$(cat "$battery/capacity")
        
        if [ "$(cat "$battery/status")" = Discharging ] &&
           [ "$capacity" -le 15 ]; then
            [ -e "$marker" ] ||
                "$notify_send" -u critical "Akku fast leer" "Noch $capacity %"
            touch "$marker"
        else
            rm -f "$marker"
        fi
    done
    
    sleep 60
done
