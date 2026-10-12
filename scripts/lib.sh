# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

# shellcheck shell=bash

readonly LUKS_NAME="guix-root"

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

function run_target {
    local repo="$1"
    shift
    (cd "${repo}" && GUILE_LOAD_PATH="${repo}" guix repl -- scripts/target.scm "$@")
}

function install_host {
    local repo="$1" host="$2" target="$3" cache="$4"
    XDG_CACHE_HOME="${cache}" repo_guix "${repo}" system init "hosts/${host}/system.scm" "${target}"
}

function ask_password_hash {
    local repo="$1" name="$2" password again hash
    while true; do
        IFS= read -rsp "Password for ${name}: " password && echo >&2
        IFS= read -rsp "Repeat password for ${name}: " again && echo >&2
        [[ -n "${password}" && "${password}" == "${again}" ]] && break
        err "Passwords are empty or do not match"
    done
    hash="$(printf '%s\n' "${password}" | run_target "${repo}" hash-password)"
    [[ "${hash}" == "\$6\$"* ]] || die "Could not hash the password for ${name}"
    printf '%s\n' "${hash}"
}

function store_password_hash {
    local repo="$1" host="$2" root="$3" name="$4" hash="$5"
    printf '%s\n' "${hash}" | run_target "${repo}" store-password-hash "${host}" "${root}" "${name}"
}
