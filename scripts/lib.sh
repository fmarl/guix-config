# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

# shellcheck shell=bash

readonly LUKS_NAME="guix-root"
readonly BTRFS_OPTIONS="compress=zstd:3,discard=async"
# subvolume:mount point:flags
readonly SUBVOLUMES=(
    "@:/:"
    "@home:/home:no-suid no-dev"
    "@gnu:/gnu:no-suid no-dev"
    "@log:/var/log:no-suid no-dev no-exec"
    "@snapshots:/.snapshots:no-suid no-dev no-exec"
)

function err {
    printf '\033[41m%s\033[0m\n' "$*" >&2
}

function info {
    printf '\033[44m%s\033[0m\n' "$*"
}

function die {
    err "$@"
    exit 1
}

function valid_hostname {
    [[ "$1" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]
}

function write_hardware {
    local file="$1" host="$2" luks_uuid="$3" esp_uuid="$4" entry subvolume mount_point flags

    {
        cat <<EOF
(define-module (hosts ${host} hardware)
  #:use-module (gnu)
  #:use-module (common system filesystem)
  #:export (%mapped-devices
            %file-systems))

(define %mapped-devices
  (list (mapped-device
          (source (uuid "${luks_uuid}"))
          (target "${LUKS_NAME}")
          (type luks-device-mapping)
          (arguments (list #:allow-discards? #t)))))

(define %file-systems
  (append (btrfs-file-systems "/dev/mapper/${LUKS_NAME}"
                              "${BTRFS_OPTIONS}"
                              '(
EOF
        for entry in "${SUBVOLUMES[@]}"; do
            IFS=: read -r subvolume mount_point flags <<<"${entry}"
            if [[ -n "${flags}" ]]; then
                printf '("%s" "%s" (%s))\n' "${mount_point}" "${subvolume}" "${flags}"
            else
                printf '("%s" "%s")\n' "${mount_point}" "${subvolume}"
            fi
        done
        cat <<EOF
                                )
                              #:dependencies %mapped-devices)
          (list (efi-file-system "${esp_uuid}"))))
EOF
    } >"${file}"

    guix style -f "${file}"
}
