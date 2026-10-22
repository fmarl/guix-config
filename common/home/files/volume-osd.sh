# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

"$wpctl" "$@"
volume=$("$wpctl" get-volume "$2")
percent=$(echo "$volume" | awk '{ print int($2 * 100 + 0.5) }')

case "$2" in
    *SOURCE*) title=Mikrofon ;;
    *) title=Lautstärke ;;
esac

case "$volume" in
    *MUTED*) title="$title (stumm)" ;;
esac
