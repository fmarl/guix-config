#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

# Partition, encrypt and format a disk and install a host from hosts/ onto it.

set -Eeuo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

readonly REPO_URL="https://codeberg.org/fmarl/guix-config.git"
readonly ESP_SIZE="1GiB"
readonly MNT="/mnt"
readonly TARGET_REPO="/etc/guix-config"
readonly REPO="${MNT}${TARGET_REPO}"

SOURCE_REPO=""
DISK_TOUCHED=""
LUKS_OPENED=""
COW_STORE=""

function usage {
    cat <<USAGE
Usage: $(basename "$0") [--repo URL] [DISK [HOSTNAME]]

  --repo URL  Repository to install from, default ${REPO_URL}
  DISK        Target disk, e.g. nvme0n1 or /dev/sda. ALL DATA ON IT IS LOST.
  HOSTNAME    Host to install, a directory in hosts/

DISK and HOSTNAME are asked for when left out.
USAGE
}

# Partition N of $DISK: nvme0n1 -> nvme0n1p1, sda -> sda1
function part {
    if [[ "${DISK}" =~ [0-9]$ ]]; then
        echo "${DISK}p$1"
    else
        echo "${DISK}$1"
    fi
}

function parse_args {
    REPO_SOURCE="${REPO_URL}"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h | --help)
                usage
                exit 0
                ;;
            --repo)
                [[ $# -ge 2 ]] || die "--repo needs a URL"
                REPO_SOURCE="$2"
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
    readonly REPO_SOURCE
}

function check_environment {
    [[ "${EUID}" -eq 0 ]] || die "Must run as root"

    local tool
    for tool in parted wipefs mkfs.fat cryptsetup mkfs.btrfs btrfs udevadm lsblk blkid \
                mountpoint herd guix getent git; do
        command -v "${tool}" >/dev/null || die "Missing tool: ${tool}"
    done

    getent hosts codeberg.org >/dev/null || die "No network connection"
}

function fetch_repo {
    SOURCE_REPO="$(mktemp -d)"
    info "Cloning ${REPO_SOURCE} ..."
    git clone --quiet "${REPO_SOURCE}" "${SOURCE_REPO}"
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
    PART_BOOT="$(part 1)"
    PART_ROOT="$(part 2)"
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
        mapfile -t hosts < <(find "${SOURCE_REPO}/hosts" -mindepth 2 -maxdepth 2 \
                                  -name system.scm -printf '%h\n' | xargs -rn1 basename | sort)
        [[ ${#hosts[@]} -gt 0 ]] || die "Found no hosts in ${REPO_SOURCE}"

        PS3="Host to install: "
        select HOST in "${hosts[@]}"; do
            [[ -n "${HOST}" ]] && break
        done
        [[ -n "${HOST}" ]] || die "No host selected"
    fi

    valid_hostname "${HOST}" || die "Invalid hostname: ${HOST}"
    readonly HOST
}

function installer_guix_is_pinned {
    local described commit
    described="$(guix describe -f channels 2>/dev/null)" || return 1
    while read -r commit; do
        [[ "${described}" == *"\"${commit}\""* ]] || return 1
    done < <(sed -n 's/.*(commit "\([0-9a-f]*\)").*/\1/p' "${SOURCE_REPO}/channels-lock.scm")
}

function preflight {
    [[ -b "${DISK}" ]] || die "${DISK} is not a block device"

    local type mounts
    type="$(lsblk -dno TYPE "${DISK}")"
    mounts="$(lsblk -no MOUNTPOINTS "${DISK}")"
    [[ "${type}" == "disk" ]] || die "${DISK} is not a whole disk"
    [[ -z "${mounts//[[:space:]]/}" ]] || die "${DISK} has mounted partitions"
    ! mountpoint -q "${MNT}" || die "${MNT} is already a mountpoint"
    [[ ! -e "/dev/mapper/${LUKS_NAME}" ]] || die "/dev/mapper/${LUKS_NAME} is already open"

    local system="${SOURCE_REPO}/hosts/${HOST}/system.scm"
    [[ -f "${system}" ]] || die "hosts/${HOST}/system.scm does not exist"
    grep -q "(hosts ${HOST} hardware)" "${system}" ||
        die "hosts/${HOST}/system.scm does not use (hosts ${HOST} hardware)"

    if installer_guix_is_pinned; then
        GUIX=(guix)
    else
        err "Warning: guix differs from channels-lock.scm, using time-machine"
        GUIX=(guix time-machine -C "${REPO}/channels-lock.scm" --)
    fi
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
    mkfs.fat -F 32 -n BOOT "${PART_BOOT}"
}

function setup_luks {
    info "Setting up LUKS2 on ${PART_ROOT} ..."
    # GRUB can only unlock PBKDF2 key slots
    cryptsetup luksFormat --batch-mode --verify-passphrase --type luks2 \
        --pbkdf pbkdf2 "${PART_ROOT}"

    LUKS_OPENED=1
    cryptsetup open --allow-discards "${PART_ROOT}" "${LUKS_NAME}"
}

function setup_btrfs {
    local dev="/dev/mapper/${LUKS_NAME}" entry subvolume mount_point
    info "Setting up btrfs on ${dev} ..."
    mkfs.btrfs -L guix "${dev}"

    mount "${dev}" "${MNT}"
    for entry in "${SUBVOLUMES[@]}"; do
        btrfs subvolume create "${MNT}/${entry%%:*}"
    done
    umount "${MNT}"

    for entry in "${SUBVOLUMES[@]}"; do
        IFS=: read -r subvolume mount_point _ <<<"${entry}"
        mkdir -p "${MNT}${mount_point}"
        mount -o "subvol=${subvolume},${BTRFS_OPTIONS}" "${dev}" "${MNT}${mount_point}"
    done

    mkdir -p "${MNT}/boot/efi"
    mount -t vfat -o umask=0077 "${PART_BOOT}" "${MNT}/boot/efi"
}

function copy_repo {
    info "Copying the repository to ${REPO} ..."
    mkdir -p "${REPO}"
    cp -rT "${SOURCE_REPO}" "${REPO}"
}

function write_host_hardware {
    local file="${REPO}/hosts/${HOST}/hardware.scm"
    info "Writing ${file} ..."
    write_hardware "${file}" "${HOST}" \
        "$(blkid -s UUID -o value "${PART_ROOT}")" \
        "$(blkid -s UUID -o value "${PART_BOOT}")"
}

function repo_guix {
    (cd "${REPO}" &&
         GUILE_LOAD_PATH="${REPO}" XDG_CACHE_HOME="${MNT}/var/cache/bootstrap" \
         "${GUIX[@]}" "$@")
}

function install_system {
    info "Installing hosts/${HOST}/system.scm ..."
    herd start cow-store "${MNT}"
    COW_STORE=1
    repo_guix system init "hosts/${HOST}/system.scm" "${MNT}"
}

function account_names {
    repo_guix repl -- /dev/stdin <<EOF
(use-modules (gnu system) (gnu system accounts))
(for-each (lambda (account)
            (unless (or (user-account-system? account)
                        (string=? (user-account-name account) "root"))
              (display (user-account-name account))
              (newline)))
          (operating-system-users
           (module-ref (resolve-interface '(hosts ${HOST} system)) '%system)))
EOF
}

function hash_password {
    guix repl -- /dev/fd/3 3<<'EOF'
(use-modules (ice-9 rdelim) (rnrs io ports))
(define alphabet "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789./")
(define salt
  (call-with-input-file "/dev/urandom"
    (lambda (port)
      (list->string
       (map (lambda (_)
              (string-ref alphabet (modulo (get-u8 port) 64)))
            (iota 16))))
    #:binary #t))
(display (crypt (read-line) (string-append "$6$" salt "$")))
EOF
}

function shadow_entry {
    local shadow="$1" name="$2" hash="$3" days
    days=$(( $(date +%s) / 86400 ))
    sed -i "/^${name}:/d" "${shadow}"
    printf '%s:%s:%s::::::\n' "${name}" "${hash}" "${days}" >>"${shadow}"
}

function set_passwords {
    local shadow="${MNT}/etc/shadow" name password again hash
    local -a names
    mapfile -t names < <(account_names)
    [[ ${#names[@]} -gt 0 ]] || die "Found no user accounts in hosts/${HOST}/system.scm"

    mkdir -p "${MNT}/etc"
    touch "${shadow}"
    chmod 600 "${shadow}"

    shadow_entry "${shadow}" root '!'

    for name in "${names[@]}"; do
        while true; do
            read -rsp "Password for ${name}: " password && echo
            read -rsp "Repeat password for ${name}: " again && echo
            [[ -n "${password}" && "${password}" == "${again}" ]] && break
            err "Passwords are empty or do not match"
        done
        hash="$(hash_password <<<"${password}")"
        [[ "${hash}" == "\$6\$"* ]] || die "Could not hash the password for ${name}"
        shadow_entry "${shadow}" "${name}" "${hash}"
    done
}

function cleanup {
    local status=$?
    [[ -z "${SOURCE_REPO}" ]] || rm -rf "${SOURCE_REPO}"
    [[ "${status}" -ne 0 && -n "${DISK_TOUCHED}" ]] || return 0

    err "Failed with exit code ${status}, rolling back ..."

    if [[ -n "${COW_STORE}" ]]; then
        herd stop cow-store || true
    fi
    if mountpoint -q "${MNT}"; then
        umount -R "${MNT}" || true
    fi
    if [[ -n "${LUKS_OPENED}" && -e "/dev/mapper/${LUKS_NAME}" ]]; then
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
    preflight
    confirm

    partition_disk
    setup_luks
    setup_btrfs
    copy_repo
    write_host_hardware
    install_system
    set_passwords
    rm -rf "${MNT}/var/cache/bootstrap"

    info "Done. After the first login run in ${TARGET_REPO}:"
    info "  guix shell -m manifest.scm -- make post-install"
}

main "$@"
