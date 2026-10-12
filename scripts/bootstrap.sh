#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

# Partition, optionally encrypt, and format a disk and install a host from
# hosts/ onto it.

set -Eeuo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

readonly DEFAULT_REPO_URL="https://codeberg.org/fmarl/guix-config.git"
readonly ESP_SIZE="1GiB"
readonly MNT="/mnt"

REPO=""
PERSIST=""
LUKS_UUID=""
LUKS_TARGET=""
ESP_UUID=""
BTRFS_KIND=""
BTRFS_ID=""
USERS=()
HASHES=()
DISK_TOUCHED=""
LUKS_OPENED=""
COW_STORE=""

function usage {
    cat <<USAGE
Usage: $(basename "$0") [--repo URL] [DISK [HOSTNAME]]

  --repo URL  Repository to install from, default ${DEFAULT_REPO_URL}
  DISK        Target disk, e.g. nvme0n1 or /dev/sda. ALL DATA ON IT IS LOST.
  HOSTNAME    Host to install, a directory in hosts/

DISK and HOSTNAME are asked for when left out.
USAGE
}

function parse_args {
    REPO_URL="${DEFAULT_REPO_URL}"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h | --help)
                usage
                exit 0
                ;;
            --repo)
                [[ $# -ge 2 ]] || die "--repo needs a URL"
                REPO_URL="$2"
                shift 2
                ;;
            -*)
                usage >&2
                exit 1
                ;;
            *) break ;;
        esac
    done

    if [[ $# -gt 2 ]]; then
        usage >&2
        exit 1
    fi

    DISK="${1-}"
    HOST="${2-}"
    readonly REPO_URL
}

function check_environment {
    [[ "${EUID}" -eq 0 ]] || die "Must run as root"

    local tool
    for tool in parted wipefs mkfs.fat mkfs.btrfs btrfs udevadm lsblk mountpoint herd guix git; do
        command -v "${tool}" >/dev/null || die "Missing tool: ${tool}"
    done
}

function host_scm {
    (cd "${REPO}" && GUILE_LOAD_PATH="${REPO}" guix repl -- scripts/host.scm "$@")
}

function pinned_guix {
    (cd "${REPO}" && GUILE_LOAD_PATH="${REPO}" XDG_CACHE_HOME="${CACHE}" "${GUIX[@]}" "$@")
}

function fetch_repo {
    REPO="$(mktemp -d -p /run)"
    info "Cloning ${REPO_URL} ..."
    git clone --quiet "${REPO_URL}" "${REPO}"
}

function select_disk {
    if [[ -z "${DISK}" ]]; then
        local -a disks
        mapfile -t disks < <(lsblk -dnpo NAME,TYPE | awk '$2 == "disk" { print $1 }')
        [[ ${#disks[@]} -gt 0 ]] || die "Found no disks"

        lsblk -dpo NAME,SIZE,MODEL "${disks[@]}"
        PS3="Disk to install on: "
        select DISK in "${disks[@]}"; do
            [[ -n "${DISK}" ]] && break
        done
        [[ -n "${DISK}" ]] || die "No disk selected"
    fi

    [[ "${DISK}" == /dev/* ]] || DISK="/dev/${DISK}"
    # nvme0n1 and mmcblk0 separate the partition number with a p
    local separator=""
    [[ "${DISK}" =~ [0-9]$ ]] && separator="p"
    PART_BOOT="${DISK}${separator}1"
    PART_ROOT="${DISK}${separator}2"
    readonly DISK PART_BOOT PART_ROOT
}

function select_host {
    local machine
    if [[ -z "${HOST}" && -r /etc/guix-config-machine ]]; then
        machine="$(</etc/guix-config-machine)"
        [[ "${machine}" == generic ]] || HOST="${machine}"
    fi

    if [[ -z "${HOST}" ]]; then
        local -a hosts
        mapfile -t hosts < <(find "${REPO}/hosts" -mindepth 2 -maxdepth 2 \
                                  -name system.scm -printf '%h\n' | xargs -rn1 basename | sort)
        [[ ${#hosts[@]} -gt 0 ]] || die "Found no hosts in ${REPO_URL}"

        PS3="Host to install: "
        select HOST in "${hosts[@]}"; do
            [[ -n "${HOST}" ]] && break
        done
        [[ -n "${HOST}" ]] || die "No host selected"
    fi

    valid_hostname "${HOST}" || die "Invalid hostname: ${HOST}"
    [[ -f "${REPO}/hosts/${HOST}/system.scm" ]] || die "Found no hosts/${HOST}/system.scm"
    readonly HOST
}

function select_guix {
    if guix repl -- "${REPO}/scripts/guix-pinned.scm" "${REPO}/channels-lock.scm"; then
        GUIX=(guix)
    else
        err "Warning: guix differs from channels-lock.scm, using time-machine"
        GUIX=(guix time-machine -C "${REPO}/channels-lock.scm" --)
    fi
    readonly GUIX
}

function read_layout {
    local facts key first second
    facts="$(host_scm layout "${HOST}")" || die "Could not evaluate hosts/${HOST}/hardware.scm"
    while read -r key first second; do
        case "${key}" in
            persist) PERSIST="${first}" ;;
            luks)
                LUKS_UUID="${first}"
                LUKS_TARGET="${second}"
                ;;
            esp) ESP_UUID="${first}" ;;
            btrfs)
                BTRFS_KIND="${first}"
                BTRFS_ID="${second}"
                ;;
        esac
    done <<<"${facts}"

    INSTALLED_REPO="${PERSIST}/etc/guix-config"
    CACHE="${MNT}${PERSIST}/var/cache/bootstrap"
    if [[ -n "${LUKS_UUID}" ]]; then
        ROOT_DEV="/dev/mapper/${LUKS_TARGET}"
    else
        ROOT_DEV="${PART_ROOT}"
    fi
    readonly PERSIST LUKS_UUID LUKS_TARGET ESP_UUID BTRFS_KIND BTRFS_ID INSTALLED_REPO CACHE ROOT_DEV
}

function preflight {
    [[ -b "${DISK}" ]] || die "${DISK} is not a block device"
    [[ "$(lsblk -dno TYPE "${DISK}")" == disk ]] || die "${DISK} is not a whole disk"
    [[ -z "$(lsblk -no MOUNTPOINTS "${DISK}" | tr -d '[:space:]')" ]] || die "${DISK} has mounted partitions"
    ! mountpoint -q "${MNT}" || die "${MNT} is already a mountpoint"

    [[ "${ESP_UUID}" =~ ^[0-9A-F]{4}-[0-9A-F]{4}$ ]] ||
        die "hosts/${HOST}/hardware.scm has no FAT volume ID as ESP UUID: ${ESP_UUID}"
    if [[ -n "${LUKS_UUID}" ]]; then
        command -v cryptsetup >/dev/null || die "Missing tool: cryptsetup"
        [[ ! -e "${ROOT_DEV}" ]] || die "${ROOT_DEV} is already open"
    fi
    case "${BTRFS_KIND}" in
        uuid | label) ;;
        device)
            [[ "${BTRFS_ID}" == "${ROOT_DEV}" ]] ||
                die "hosts/${HOST}/hardware.scm mounts ${BTRFS_ID}, expected ${ROOT_DEV}, a UUID or a label"
            ;;
        *) die "hosts/${HOST}/hardware.scm mounts no btrfs file system" ;;
    esac
}

function confirm {
    lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MODEL "${DISK}"
    info "Installing ${HOST} on ${DISK}${LUKS_UUID:+, encrypted}${PERSIST:+, impermanent}"
    err "ALL DATA ON ${DISK} WILL BE DESTROYED."

    local answer
    read -rp "Type the disk path (${DISK}) to continue: " answer
    [[ "${answer}" == "${DISK}" ]] || die "Aborted"
}

function partition_disk {
    info "Partitioning ${DISK} (GPT, UEFI) ..."
    DISK_TOUCHED=1

    wipefs -af "${DISK}"
    parted -s "${DISK}" -- \
        mklabel gpt \
        mkpart ESP fat32 1MiB "${ESP_SIZE}" \
        set 1 esp on \
        mkpart root "${ESP_SIZE}" 100%
    udevadm settle

    # A previous install with the same layout leaves its signatures at the same offsets
    wipefs -af "${PART_BOOT}" "${PART_ROOT}"
    mkfs.fat -F 32 -n BOOT -i "${ESP_UUID/-/}" "${PART_BOOT}"
}

function setup_luks {
    [[ -n "${LUKS_UUID}" ]] || return 0

    info "Setting up LUKS2 on ${PART_ROOT} ..."
    # GRUB can only unlock PBKDF2 key slots
    cryptsetup luksFormat --batch-mode --verify-passphrase --type luks2 \
        --pbkdf pbkdf2 --uuid "${LUKS_UUID}" "${PART_ROOT}"

    LUKS_OPENED=1
    cryptsetup open --allow-discards "${PART_ROOT}" "${LUKS_TARGET}"
}

function setup_btrfs {
    info "Setting up btrfs on ${ROOT_DEV} ..."
    local -a options=(-L guix)
    case "${BTRFS_KIND}" in
        uuid) options+=(-U "${BTRFS_ID}") ;;
        label) options=(-L "${BTRFS_ID}") ;;
    esac
    mkfs.btrfs "${options[@]}" "${ROOT_DEV}"
    udevadm settle

    host_scm create-subvolumes "${HOST}"
    host_scm mount "${HOST}" "${MNT}"
    herd start cow-store "${MNT}"
    COW_STORE=1
}

function ask_passwords {
    local facts name password again hash
    facts="$(pinned_guix repl -- scripts/host.scm users "${HOST}")" ||
        die "Could not evaluate hosts/${HOST}/system.scm"
    mapfile -t USERS <<<"${facts}"
    [[ -n "${USERS[0]}" ]] || die "hosts/${HOST} has no user accounts"

    for name in "${USERS[@]}"; do
        while true; do
            IFS= read -rsp "Password for ${name}: " password && echo >&2
            IFS= read -rsp "Repeat password for ${name}: " again && echo >&2
            [[ -n "${password}" && "${password}" == "${again}" ]] && break
            err "Passwords are empty or do not match"
        done
        hash="$(printf '%s\n' "${password}" | host_scm hash-password)"
        [[ "${hash}" == "\$6\$"* ]] || die "Could not hash the password for ${name}"
        HASHES+=("${hash}")
    done
}

function install_system {
    info "Copying the repository to ${INSTALLED_REPO} ..."
    mkdir -p "${MNT}${INSTALLED_REPO}"
    cp -rT "${REPO}" "${MNT}${INSTALLED_REPO}"

    info "Installing hosts/${HOST}/system.scm ..."
    pinned_guix system init "hosts/${HOST}/system.scm" "${MNT}"
    herd stop cow-store
    COW_STORE=""

    local i
    for i in "${!USERS[@]}"; do
        printf '%s\n' "${HASHES[i]}" | host_scm store-password-hash "${HOST}" "${MNT}" "${USERS[i]}"
    done
    rm -rf "${CACHE}"
}

function cleanup {
    local status=$?
    [[ -z "${REPO}" ]] || rm -rf "${REPO}"
    [[ "${status}" -ne 0 && -n "${DISK_TOUCHED}" ]] || return 0

    err "Failed with exit code ${status}, rolling back ..."

    if [[ -n "${COW_STORE}" ]]; then
        herd stop cow-store || true
        err "cow-store leaves /tmp and /gnu/store mounted, reboot before retrying"
    fi
    if mountpoint -q "${MNT}"; then
        umount -R "${MNT}" || true
    fi
    if [[ -n "${LUKS_OPENED}" && -e "${ROOT_DEV}" ]]; then
        cryptsetup close "${LUKS_TARGET}" || true
    fi
    wipefs -af "${DISK}" >/dev/null || true
}

function main {
    parse_args "$@"
    check_environment

    trap cleanup EXIT
    fetch_repo
    select_disk
    select_host
    select_guix
    read_layout
    preflight
    confirm

    partition_disk
    setup_luks
    setup_btrfs
    ask_passwords
    install_system

    info "Done. After the first login run in ${INSTALLED_REPO}:"
    info "  guix shell -m manifest.scm -- make post-install"
}

main "$@"
