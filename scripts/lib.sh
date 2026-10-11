# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

# shellcheck shell=bash

readonly LUKS_NAME="guix-root"
readonly BTRFS_OPTIONS="compress=zstd:3,discard=async"

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

function select_guix {
    local repo="$1"
    if guix repl -- "${repo}/scripts/guix-pinned.scm" "${repo}/channels-lock.scm"; then
        GUIX=(guix)
    else
        err "Warning: guix differs from channels-lock.scm, using time-machine"
        GUIX=(guix time-machine -C "${repo}/channels-lock.scm" --)
    fi
}

function repo_guix {
    local repo="$1"
    shift
    (cd "${repo}" && GUILE_LOAD_PATH="${repo}" "${GUIX[@]}" "$@")
}

function parse_host_facts {
    local host="$1" facts="$2" key first second
    declare -g HOST_PERSIST="" HOST_LUKS_UUID="" HOST_LUKS_TARGET="" HOST_ESP_UUID=""
    declare -ga HOST_SUBVOLUMES=() HOST_PERSISTED=() HOST_USERS=()
    while read -r key first second; do
        case "${key}" in
            persist) HOST_PERSIST="${first}" ;;
            subvolume) HOST_SUBVOLUMES+=("${first}:${second#-}") ;;
            luks)
                HOST_LUKS_UUID="${first}"
                HOST_LUKS_TARGET="${second}"
                ;;
            esp) HOST_ESP_UUID="${first}" ;;
            persisted) HOST_PERSISTED+=("${first}") ;;
            user) HOST_USERS+=("${first}") ;;
        esac
    done <<<"${facts}"

    [[ -n "${HOST_ESP_UUID}" ]] || die "hosts/${host} has no EFI system partition"
}

function read_layout {
    local repo="$1" host="$2" facts
    facts="$(cd "${repo}" && GUILE_LOAD_PATH="${repo}" guix repl -- scripts/host-info.scm layout "${host}")" ||
        die "Could not evaluate hosts/${host}/hardware.scm"
    parse_host_facts "${host}" "${facts}"
}

function read_system {
    local repo="$1" host="$2" cache="$3" facts
    facts="$(XDG_CACHE_HOME="${cache}" repo_guix "${repo}" repl -- scripts/host-info.scm system "${host}")" ||
        die "Could not evaluate hosts/${host}/system.scm"
    parse_host_facts "${host}" "${facts}"
    [[ ${#HOST_USERS[@]} -gt 0 ]] || die "hosts/${host} has no user accounts"
}

function create_subvolumes {
    local dev="$1" top entry
    top="$(mktemp -d)"
    mount "${dev}" "${top}"
    for entry in "${HOST_SUBVOLUMES[@]}"; do
        btrfs subvolume create "${top}/${entry%%:*}"
    done
    umount "${top}"
    rmdir "${top}"
}

function mount_host {
    local dev="$1" esp="$2" target="$3" entry subvolume mount_point

    [[ -z "${HOST_PERSIST}" ]] || mount -t tmpfs -o mode=0755 none "${target}"
    for entry in "${HOST_SUBVOLUMES[@]}"; do
        IFS=: read -r subvolume mount_point <<<"${entry}"
        [[ -n "${mount_point}" ]] || continue
        mkdir -p "${target}${mount_point}"
        mount -o "subvol=${subvolume},${BTRFS_OPTIONS}" "${dev}" "${target}${mount_point}"
    done

    if [[ -n "${HOST_PERSIST}" ]]; then
        local persist="${target}${HOST_PERSIST}"
        mkdir -p "${persist}/var/guix" "${target}/var/guix" "${persist}/var/tmp" "${target}/tmp"
        chmod 1777 "${persist}/var/tmp"
        mount --bind "${persist}/var/guix" "${target}/var/guix"
        mount --bind "${persist}/var/tmp" "${target}/tmp"
    fi

    mkdir -p "${target}/boot/efi"
    mount -t vfat -o umask=0077 "${esp}" "${target}/boot/efi"
}

function install_host {
    local repo="$1" host="$2" target="$3" cache="$4"
    XDG_CACHE_HOME="${cache}" repo_guix "${repo}" system init "hosts/${host}/system.scm" "${target}"
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

function ask_password_hash {
    local name="$1" password again hash
    while true; do
        read -rsp "Password for ${name}: " password && echo >&2
        read -rsp "Repeat password for ${name}: " again && echo >&2
        [[ -n "${password}" && "${password}" == "${again}" ]] && break
        err "Passwords are empty or do not match"
    done
    hash="$(hash_password <<<"${password}")"
    [[ "${hash}" == "\$6\$"* ]] || die "Could not hash the password for ${name}"
    printf '%s\n' "${hash}"
}

function write_persisted_hash {
    local persist="$1" name="$2" hash="$3"
    local directory="${persist}/etc/shadow.d"
    mkdir -p "${directory}"
    chmod 0700 "${directory}"
    (umask 077 && printf '%s\n' "${hash}" >"${directory}/${name}")
}
