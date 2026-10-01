#!/usr/bin/env bash
# Partition, encrypt, format and mount a disk for a Guix installation into /mnt.

set -Eeuo pipefail

readonly LUKS_NAME="guix-root"
readonly ESP_SIZE="1GiB"
readonly MNT="/mnt"
readonly BTRFS_OPTIONS="compress=zstd:3,discard=async"
# subvolume:mount point
readonly SUBVOLUMES=("@:/" "@home:/home" "@gnu:/gnu" "@log:/var/log" "@snapshots:/.snapshots")

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO

DISK_TOUCHED=""
LUKS_OPENED=""

function usage {
    cat <<USAGE
Usage: $(basename "$0") DISK HOSTNAME

  DISK      Target disk, e.g. nvme0n1 or /dev/sda. ALL DATA ON IT IS LOST.
  HOSTNAME  Host to install, should match a directory in hosts/
USAGE
}

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

# Partition N of $DISK: nvme0n1 -> nvme0n1p1, sda -> sda1
function part {
    if [[ "${DISK}" =~ [0-9]$ ]]; then
        echo "${DISK}p$1"
    else
        echo "${DISK}$1"
    fi
}

function parse_args {
    if [[ "${1-}" == "-h" || "${1-}" == "--help" ]]; then
        usage
        exit 0
    fi

    if [[ $# -ne 2 ]]; then
        usage >&2
        exit 1
    fi

    DISK="$1"
    [[ "${DISK}" == /dev/* ]] || DISK="/dev/${DISK}"
    HOST="$2"

    [[ "${HOST}" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]] || die "Invalid hostname: ${HOST}"

    PART_BOOT="$(part 1)"
    PART_ROOT="$(part 2)"
    readonly DISK HOST PART_BOOT PART_ROOT
}

function preflight {
    [[ "${EUID}" -eq 0 ]] || die "Must run as root"

    local tool
    for tool in parted wipefs mkfs.fat cryptsetup mkfs.btrfs btrfs udevadm lsblk blkid mountpoint; do
        command -v "${tool}" >/dev/null || die "Missing tool: ${tool}"
    done

    [[ -b "${DISK}" ]] || die "${DISK} is not a block device"

    local type mounts
    type="$(lsblk -dno TYPE "${DISK}")"
    mounts="$(lsblk -no MOUNTPOINTS "${DISK}")"
    [[ "${type}" == "disk" ]] || die "${DISK} is not a whole disk"
    [[ -z "${mounts//[[:space:]]/}" ]] || die "${DISK} has mounted partitions"
    ! mountpoint -q "${MNT}" || die "${MNT} is already a mountpoint"
    [[ ! -e "/dev/mapper/${LUKS_NAME}" ]] || die "/dev/mapper/${LUKS_NAME} is already open"

    if [[ ! -d "${REPO}/hosts/${HOST}" ]]; then
        err "Warning: ${REPO}/hosts/${HOST} does not exist yet"
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
        subvolume="${entry%%:*}"
        mount_point="${MNT}${entry#*:}"
        mkdir -p "${mount_point}"
        mount -o "subvol=${subvolume},${BTRFS_OPTIONS}" "${dev}" "${mount_point}"
    done

    mkdir -p "${MNT}/boot/efi"
    mount -t vfat -o umask=0077 "${PART_BOOT}" "${MNT}/boot/efi"
}

function cleanup {
    local status=$?
    [[ "${status}" -eq 0 ]] && return

    err "Failed with exit code ${status}, rolling back ..."

    if mountpoint -q "${MNT}"; then
        umount -R "${MNT}" || true
    fi
    if [[ -n "${LUKS_OPENED}" && -e "/dev/mapper/${LUKS_NAME}" ]]; then
        cryptsetup close "${LUKS_NAME}" || true
    fi
    if [[ -n "${DISK_TOUCHED}" ]]; then
        wipefs -af "${DISK}" >/dev/null || true
    fi
}

function next_steps {
    local luks_uuid esp_uuid
    luks_uuid="$(blkid -s UUID -o value "${PART_ROOT}")"
    esp_uuid="$(blkid -s UUID -o value "${PART_BOOT}")"

    info "Done. ${DISK} is mounted at ${MNT}. Next steps:"
    cat <<STEPS
  1. hosts/${HOST}/system.scm, e.g. copied from hosts/thinkpad, with
       mapped-device source: (uuid "${luks_uuid}")
       ESP:                  (uuid "${esp_uuid}" 'fat32)
       subvolumes:           ${SUBVOLUMES[*]}
  2. Let the store use the target disk:
       herd start cow-store ${MNT}
  3. Install:
       cd ${REPO} && GUILE_LOAD_PATH=\$PWD guix time-machine -C channels-lock.scm -- \\
           system init hosts/${HOST}/system.scm ${MNT}
  4. Set the user password:
       chroot ${MNT} passwd <user>
STEPS
}

function main {
    parse_args "$@"
    preflight
    confirm

    trap cleanup EXIT
    partition_disk
    setup_luks
    setup_btrfs
    trap - EXIT

    next_steps
}

main "$@"
