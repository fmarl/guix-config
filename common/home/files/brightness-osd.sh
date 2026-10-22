# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

"$brightnessctl" -q --class=backlight set "$1"
percent=$("$brightnessctl" -m --class=backlight | cut -d, -f4 | tr -d %)
title=Helligkeit
