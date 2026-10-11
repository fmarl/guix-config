#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

# Move an installed host from @ to the impermanent layout.

set -Eeuo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
readonly REPO
readonly MNT="/mnt"
readonly DEV="/dev/mapper/${LUKS_NAME}"
readonly CACHE="${MNT}/persist/var/cache/migrate"

TOP=""
CREATED=""
COW_STORE=""
INSTALLING=""

function usage {
    cat <<USAGE
Usage: $(basename "$0") [HOSTNAME]

Run as root from the installer.  HOSTNAME is taken from the installer image
when left out.
USAGE
}

function parse_args {
    if [[ $# -gt 1 || "${1-}" == -* ]]; then
        usage >&2
        exit 1
    fi

    HOST="${1-}"
    if [[ -z "${HOST}" && -r /etc/guix-config-machine ]]; then
        HOST="$(</etc/guix-config-machine)"
    fi
    [[ -n "${HOST}" && "${HOST}" != generic ]] || die "No host given"
    valid_hostname "${HOST}" || die "Invalid hostname: ${HOST}"
    readonly HOST
}

function check_environment {
    [[ "${EUID}" -eq 0 ]] || die "Must run as root"

    local tool
    for tool in cryptsetup btrfs mountpoint herd guix; do
        command -v "${tool}" >/dev/null || die "Missing tool: ${tool}"
    done
}

function subvolume_at {
    local mount_point="$1" entry
    for entry in "${HOST_SUBVOLUMES[@]}"; do
        if [[ "${entry#*:}" == "${mount_point}" ]]; then
            echo "${entry%%:*}"
            return
        fi
    done
    die "hosts/${HOST}/hardware.scm mounts nothing at ${mount_point}"
}

function check_layout {
    [[ -n "${HOST_PERSIST}" ]] ||
        die "hosts/${HOST}/hardware.scm does not use impermanent-file-systems"
    [[ -n "${HOST_LUKS_UUID}" && "${HOST_LUKS_TARGET}" == "${LUKS_NAME}" ]] ||
        die "hosts/${HOST}/hardware.scm does not map a LUKS device to ${LUKS_NAME}"

    PERSIST_SUBVOLUME="$(subvolume_at "${HOST_PERSIST}")"
    BOOT_SUBVOLUME="$(subvolume_at /boot)"
    readonly PERSIST_SUBVOLUME BOOT_SUBVOLUME
}

function open_disk {
    if [[ ! -e "${DEV}" ]]; then
        info "Opening the LUKS device ${HOST_LUKS_UUID} ..."
        cryptsetup open --allow-discards "/dev/disk/by-uuid/${HOST_LUKS_UUID}" "${LUKS_NAME}"
    fi

    TOP="$(mktemp -d)"
    mount -o subvolid=5 "${DEV}" "${TOP}"
}

function preflight {
    [[ "${REPO}/" != "${MNT}/"* ]] ||
        die "${REPO} is below ${MNT}, mount @home elsewhere, e.g. at /media/home"
    ! mountpoint -q "${MNT}" || die "${MNT} is already a mountpoint"
    [[ -d "${TOP}/@/boot/grub" ]] || die "Found no @/boot/grub, is ${HOST} installed?"

    local entry subvolume
    for entry in "${HOST_SUBVOLUMES[@]}"; do
        subvolume="${entry%%:*}"
        if [[ "${subvolume}" == "${PERSIST_SUBVOLUME}" || "${subvolume}" == "${BOOT_SUBVOLUME}" ]]; then
            [[ ! -e "${TOP}/${subvolume}" ]] || die "${subvolume} exists already"
        else
            [[ -d "${TOP}/${subvolume}" ]] || die "${subvolume} does not exist"
        fi
    done
}

function confirm {
    info "Migrating ${HOST} to the impermanent layout:"
    echo "  create:  ${PERSIST_SUBVOLUME} ${BOOT_SUBVOLUME}"
    echo "  copy:    @/boot, the persisted directories and the password hashes"
    echo "  install: hosts/${HOST}/system.scm from ${REPO}"
    echo "  reset:   /var/guix, rebuild Guix Home after the first boot"

    local answer
    read -rp "Type ${HOST} to continue: " answer
    [[ "${answer}" == "${HOST}" ]] || die "Aborted"
}

function create_new_subvolumes {
    CREATED=1
    btrfs subvolume create "${TOP}/${PERSIST_SUBVOLUME}" "${TOP}/${BOOT_SUBVOLUME}"
    cp -a --reflink=always "${TOP}/@/boot/." "${TOP}/${BOOT_SUBVOLUME}/"
}

function mount_target {
    mount_host "${DEV}" "/dev/disk/by-uuid/${HOST_ESP_UUID}" "${MNT}"
    herd start cow-store "${MNT}"
    COW_STORE=1
    read_system "${REPO}" "${HOST}" "${CACHE}"
}

function copy_directory {
    local source="$1" target="$2"
    mkdir -p "${target}"
    cp -a --reflink=always "${source}/." "${target}/"
    chown --reference="${source}" "${target}"
    chmod --reference="${source}" "${target}"
}

function copy_persisted_directories {
    local directory
    for directory in "${HOST_PERSISTED[@]}"; do
        if [[ "${directory}" == /var/guix ]]; then
            continue
        elif [[ -d "${TOP}/@${directory}" ]]; then
            info "Copying ${directory} ..."
            copy_directory "${TOP}/@${directory}" "${TOP}/${PERSIST_SUBVOLUME}${directory}"
        else
            err "Skipping ${directory}, it does not exist in @"
        fi
    done
}

function copy_password_hashes {
    local user hash
    for user in "${HOST_USERS[@]}"; do
        hash="$(awk -F: -v user="${user}" '$1 == user { print $2 }' "${TOP}/@/etc/shadow")"
        if [[ "${hash}" != "\$"* ]]; then
            err "${user} has no password yet"
            hash="$(ask_password_hash "${user}")"
        fi
        write_persisted_hash "${TOP}/${PERSIST_SUBVOLUME}" "${user}" "${hash}"
    done
}

function install_system {
    info "Installing hosts/${HOST}/system.scm ..."
    INSTALLING=1
    install_host "${REPO}" "${HOST}" "${MNT}" "${CACHE}"
    rm -rf "${CACHE}"
    herd stop cow-store
    COW_STORE=""
}

function cleanup {
    local status=$?
    if [[ "${status}" -ne 0 && -n "${INSTALLING}" ]]; then
        err "Failed with exit code ${status} during the installation, retry with:"
        err "  cd ${REPO} && XDG_CACHE_HOME=${CACHE} GUILE_LOAD_PATH=. ${GUIX[*]} system init hosts/${HOST}/system.scm ${MNT}"
    elif [[ "${status}" -ne 0 ]]; then
        err "Failed with exit code ${status}, rolling back ..."
        if [[ -n "${COW_STORE}" ]]; then
            herd stop cow-store || true
        fi
        if mountpoint -q "${MNT}"; then
            umount -R "${MNT}" || true
        fi
        if [[ -n "${CREATED}" ]]; then
            btrfs subvolume delete "${TOP}/${PERSIST_SUBVOLUME}" "${TOP}/${BOOT_SUBVOLUME}" || true
        fi
    fi
    if [[ -n "${TOP}" ]] && mountpoint -q "${TOP}"; then
        umount "${TOP}" && rmdir "${TOP}"
    fi
}

function main {
    parse_args "$@"
    check_environment
    select_guix "${REPO}"
    read_layout "${REPO}" "${HOST}"
    check_layout

    trap cleanup EXIT
    open_disk
    preflight
    confirm

    create_new_subvolumes
    mount_target
    copy_persisted_directories
    copy_password_hashes
    install_system

    info "Done. After the first boot run in the repository:"
    info "  guix pull && make home"
    info "To boot @ until the next guix gc, press c in GRUB and enter:"
    info "  search --set=root --file /@/boot/grub/grub.cfg"
    info "  configfile /@/boot/grub/grub.cfg"
    info "Delete @ once everything works:"
    info "  sudo btrfs subvolume delete /.btrfs/@"
}

main "$@"
