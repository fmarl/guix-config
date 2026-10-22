# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

id_file="$XDG_RUNTIME_DIR/$osd_name"
id=$(cat "$id_file" 2>/dev/null)

"$notify_send" -a osd -u low -t 1500 -p -h "int:value:${percent:-0}" \
    -r "${id:-0}" "$title" >"$id_file.$$" &&
    mv "$id_file.$$" "$id_file"

rm -f "$id_file.$$"
