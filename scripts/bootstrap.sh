#!/usr/bin/env bash
# Partition, encrypt and format a disk and install a host from hosts/ onto it.

set -Eeuo pipefail

readonly LUKS_NAME="guix-root"
readonly ESP_SIZE="1GiB"
readonly MNT="/mnt"
readonly BTRFS_OPTIONS="compress=zstd:3,discard=async"
# subvolume:mount point
readonly SUBVOLUMES=("@:/" "@home:/home" "@gnu:/gnu" "@log:/var/log" "@snapshots:/.snapshots")
readonly TARGET_REPO="/etc/guix-config"

SOURCE_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
readonly SOURCE_REPO
readonly REPO="${MNT}${TARGET_REPO}"

DISK_TOUCHED=""
LUKS_OPENED=""
COW_STORE=""

function usage {
    cat <<USAGE
Usage: $(basename "$0") DISK HOSTNAME

  DISK      Target disk, e.g. nvme0n1 or /dev/sda. ALL DATA ON IT IS LOST.
  HOSTNAME  Host to install, a directory in hosts/
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

function installer_guix_is_pinned {
    local described commit
    described="$(guix describe -f channels 2>/dev/null)" || return 1
    for commit in $(sed -n 's/.*(commit "\([0-9a-f]*\)").*/\1/p' "${SOURCE_REPO}/channels-lock.scm"); do
        [[ "${described}" == *"\"${commit}\""* ]] || return 1
    done
}

function preflight {
    [[ "${EUID}" -eq 0 ]] || die "Must run as root"

    local tool
    for tool in parted wipefs mkfs.fat cryptsetup mkfs.btrfs btrfs udevadm lsblk blkid \
                mountpoint herd guix getent; do
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

    local system="${SOURCE_REPO}/hosts/${HOST}/system.scm"
    [[ -f "${system}" ]] || die "${system} does not exist"
    grep -q "(hosts ${HOST} hardware)" "${system}" ||
        die "${system} does not use (hosts ${HOST} hardware)"

    getent hosts codeberg.org >/dev/null || die "No network connection"

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
        subvolume="${entry%%:*}"
        mount_point="${MNT}${entry#*:}"
        mkdir -p "${mount_point}"
        mount -o "subvol=${subvolume},${BTRFS_OPTIONS}" "${dev}" "${mount_point}"
    done

    mkdir -p "${MNT}/boot/efi"
    mount -t vfat -o umask=0077 "${PART_BOOT}" "${MNT}/boot/efi"
}

function copy_repo {
    info "Copying ${SOURCE_REPO} to ${REPO} ..."
    mkdir -p "${REPO}"
    cp -rT "${SOURCE_REPO}" "${REPO}"
    chmod -R u+w "${REPO}"
}

function write_hardware {
    local file="${REPO}/hosts/${HOST}/hardware.scm" luks_uuid esp_uuid entry
    luks_uuid="$(blkid -s UUID -o value "${PART_ROOT}")"
    esp_uuid="$(blkid -s UUID -o value "${PART_BOOT}")"
    info "Writing ${file} ..."

    {
        cat <<EOF
(define-module (hosts ${HOST} hardware)
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
            printf '                                ("%s" "%s")\n' "${entry#*:}" "${entry%%:*}"
        done
        cat <<EOF
                                )
                              #:dependencies %mapped-devices)
          (list (file-system
                  (mount-point "/boot/efi")
                  (device (uuid "${esp_uuid}" 'fat32))
                  (type "vfat")
                  (options "umask=0077")))))
EOF
    } >"${file}"

    (cd "${REPO}" && guix style -f "hosts/${HOST}/hardware.scm")
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
(display "root\n")
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

function set_passwords {
    local shadow="${MNT}/etc/shadow" name password again hash days
    local -a names
    names=($(account_names))
    [[ ${#names[@]} -gt 1 ]] || die "Found no user accounts in hosts/${HOST}/system.scm"
    days=$(( $(date +%s) / 86400 ))

    mkdir -p "${MNT}/etc"
    touch "${shadow}"
    chmod 600 "${shadow}"

    for name in "${names[@]}"; do
        while true; do
            read -rsp "Password for ${name}: " password && echo
            read -rsp "Repeat password for ${name}: " again && echo
            [[ -n "${password}" && "${password}" == "${again}" ]] && break
            err "Passwords are empty or do not match"
        done
        hash="$(hash_password <<<"${password}")"
        [[ "${hash}" == '$6$'* ]] || die "Could not hash the password for ${name}"
        sed -i "/^${name}:/d" "${shadow}"
        printf '%s:%s:%s::::::\n' "${name}" "${hash}" "${days}" >>"${shadow}"
    done
}

function cleanup {
    local status=$?
    [[ "${status}" -eq 0 ]] && return

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
    if [[ -n "${DISK_TOUCHED}" ]]; then
        wipefs -af "${DISK}" >/dev/null || true
    fi
}

function main {
    parse_args "$@"
    preflight
    confirm

    trap cleanup EXIT
    partition_disk
    setup_luks
    setup_btrfs
    copy_repo
    write_hardware
    install_system
    set_passwords
    trap - EXIT
    rm -rf "${MNT}/var/cache/bootstrap"

    info "Done. Copy ${TARGET_REPO}/hosts/${HOST}/hardware.scm into the repository."
}

main "$@"
