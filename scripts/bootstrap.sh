#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

# Partition, encrypt and format a disk and install a host from hosts/ onto it.

set -Eeuo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

readonly DEFAULT_REPO_URL="https://codeberg.org/fmarl/guix-config.git"
readonly ESP_SIZE="1GiB"
readonly MNT="/mnt"
readonly DEV="/dev/mapper/${LUKS_NAME}"

CLONE_DIR=""
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

# Partition N of $DISK: nvme0n1 -> nvme0n1p1, sda -> sda1
function partition {
    if [[ "${DISK}" =~ [0-9]$ ]]; then
        echo "${DISK}p$1"
    else
        echo "${DISK}$1"
    fi
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
            *)
                break
                ;;
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
    for tool in parted wipefs mkfs.fat cryptsetup mkfs.btrfs btrfs udevadm lsblk \
                mountpoint herd guix getent git; do
        command -v "${tool}" >/dev/null || die "Missing tool: ${tool}"
    done

    getent hosts codeberg.org >/dev/null || die "No network connection"
}

function fetch_repo {
    CLONE_DIR="$(mktemp -d)"
    info "Cloning ${REPO_URL} ..."
    git clone --quiet "${REPO_URL}" "${CLONE_DIR}"
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
    PART_BOOT="$(partition 1)"
    PART_ROOT="$(partition 2)"
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
        mapfile -t hosts < <(find "${CLONE_DIR}/hosts" -mindepth 2 -maxdepth 2 \
                                  -name system.scm -printf '%h\n' | xargs -rn1 basename | sort)
        [[ ${#hosts[@]} -gt 0 ]] || die "Found no hosts in ${REPO_URL}"

        PS3="Host to install: "
        select HOST in "${hosts[@]}"; do
            [[ -n "${HOST}" ]] && break
        done
        [[ -n "${HOST}" ]] || die "No host selected"
    fi

    valid_hostname "${HOST}" || die "Invalid hostname: ${HOST}"
    readonly HOST
}

function set_paths {
    INSTALLED_REPO="${HOST_PERSIST}/etc/guix-config"
    MNT_REPO="${MNT}${INSTALLED_REPO}"
    CACHE="${MNT}${HOST_PERSIST}/var/cache/bootstrap"
    readonly INSTALLED_REPO MNT_REPO CACHE
}

function preflight {
    [[ -b "${DISK}" ]] || die "${DISK} is not a block device"

    local type mounts
    type="$(lsblk -dno TYPE "${DISK}")"
    mounts="$(lsblk -no MOUNTPOINTS "${DISK}")"
    [[ "${type}" == "disk" ]] || die "${DISK} is not a whole disk"
    [[ -z "${mounts//[[:space:]]/}" ]] || die "${DISK} has mounted partitions"
    ! mountpoint -q "${MNT}" || die "${MNT} is already a mountpoint"
    [[ ! -e "${DEV}" ]] || die "${DEV} is already open"

    [[ -n "${HOST_LUKS_UUID}" ]] || die "hosts/${HOST}/hardware.scm has no LUKS device"
    [[ "${HOST_ESP_UUID}" =~ ^[0-9A-F]{4}-[0-9A-F]{4}$ ]] ||
        die "hosts/${HOST}/hardware.scm has no FAT volume ID as ESP UUID: ${HOST_ESP_UUID}"
    [[ "${HOST_LUKS_TARGET}" == "${LUKS_NAME}" ]] ||
        die "hosts/${HOST}/hardware.scm maps LUKS to ${HOST_LUKS_TARGET}, not ${LUKS_NAME}"
}

function confirm {
    lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MODEL "${DISK}"
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
    mkfs.fat -F 32 -n BOOT -i "${HOST_ESP_UUID/-/}" "${PART_BOOT}"
}

function setup_luks {
    info "Setting up LUKS2 on ${PART_ROOT} ..."
    # GRUB can only unlock PBKDF2 key slots
    cryptsetup luksFormat --batch-mode --verify-passphrase --type luks2 \
        --pbkdf pbkdf2 --uuid "${HOST_LUKS_UUID}" "${PART_ROOT}"

    LUKS_OPENED=1
    cryptsetup open --allow-discards "${PART_ROOT}" "${LUKS_NAME}"
}

function setup_btrfs {
    info "Setting up btrfs on ${DEV} ..."
    mkfs.btrfs -L guix "${DEV}"
    create_subvolumes "${DEV}"
    mount_host "${DEV}" "${PART_BOOT}" "${MNT}"

    herd start cow-store "${MNT}"
    COW_STORE=1
}

function copy_repo {
    info "Copying the repository to ${MNT_REPO} ..."
    mkdir -p "${MNT_REPO}"
    cp -rT "${CLONE_DIR}" "${MNT_REPO}"
}

function install_system {
    info "Installing hosts/${HOST}/system.scm ..."
    install_host "${MNT_REPO}" "${HOST}" "${MNT}" "${CACHE}"
    herd stop cow-store
    COW_STORE=""
}

function set_shadow_entry {
    local shadow="$1" name="$2" hash="$3" days
    days=$(( $(date +%s) / 86400 ))
    sed -i "/^${name}:/d" "${shadow}"
    printf '%s:%s:%s::::::\n' "${name}" "${hash}" "${days}" >>"${shadow}"
}

function store_password_hash {
    local name="$1" hash="$2"
    if [[ -n "${HOST_PERSIST}" ]]; then
        write_persisted_hash "${MNT}${HOST_PERSIST}" "${name}" "${hash}"
    else
        set_shadow_entry "${MNT}/etc/shadow" "${name}" "${hash}"
    fi
}

function set_passwords {
    local name hash

    if [[ -z "${HOST_PERSIST}" ]]; then
        mkdir -p "${MNT}/etc"
        touch "${MNT}/etc/shadow"
        chmod 600 "${MNT}/etc/shadow"
    fi

    for name in "${HOST_USERS[@]}"; do
        hash="$(ask_password_hash "${name}")"
        store_password_hash "${name}" "${hash}"
    done
}

function cleanup {
    local status=$?
    [[ -z "${CLONE_DIR}" ]] || rm -rf "${CLONE_DIR}"
    [[ "${status}" -ne 0 && -n "${DISK_TOUCHED}" ]] || return 0

    err "Failed with exit code ${status}, rolling back ..."

    if [[ -n "${COW_STORE}" ]]; then
        herd stop cow-store || true
    fi
    if mountpoint -q "${MNT}"; then
        umount -R "${MNT}" || true
    fi
    if [[ -n "${LUKS_OPENED}" && -e "${DEV}" ]]; then
        cryptsetup close "${LUKS_NAME}" || true
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
    select_guix "${CLONE_DIR}"
    read_layout "${CLONE_DIR}" "${HOST}"
    set_paths
    preflight
    confirm

    partition_disk
    setup_luks
    setup_btrfs
    copy_repo
    read_system "${MNT_REPO}" "${HOST}" "${CACHE}"
    install_system
    set_passwords
    rm -rf "${CACHE}"

    info "Done. After the first login run in ${INSTALLED_REPO}:"
    info "  guix shell -m manifest.scm -- make post-install"
}

main "$@"
