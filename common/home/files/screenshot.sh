# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

geometry=$("$slurp" "$@") || exit 0
dir="$HOME/Pictures/Screenshots"
mkdir -p "$dir"
file="$dir/Screenshot from $(date '+%Y-%m-%d %H-%M-%S').png"
"$grim" -g "$geometry" "$file" &&
    "$wl_copy" --type image/png <"$file"
