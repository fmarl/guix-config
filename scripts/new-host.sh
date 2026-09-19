#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

set -Eeuo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
readonly REPO

function usage {
    cat <<USAGE
Usage: $(basename "$0") HOSTNAME
USAGE
}

function write_system {
    cat >"$1" <<EOF
(define-module (hosts ${HOST} system)
  #:use-module (gnu)
  #:use-module (nongnu packages linux)
  #:use-module (common machines)
  #:use-module (common system base)
  #:use-module (common system desktop)
  #:use-module (common system networking)
  #:use-module (hosts ${HOST} hardware)
  #:export (%system))

(define %machine
  (lookup-machine '${HOST}))

(define %system
  (base-operating-system %machine
                         #:initrd-modules (cons "dm-crypt"
                                                (base-initrd-modules linux))
                         #:firmware (list linux-firmware)
                         #:mapped-devices %mapped-devices
                         #:file-systems %file-systems
                         #:services (append (desktop-session %machine)
                                            (network-services %machine))))

%system
EOF
}

function write_home {
    cat >"$1" <<EOF
(define-module (hosts ${HOST} home)
  #:use-module (common home base)
  #:use-module (common machines)
  #:export (%home))

(define %machine
  (lookup-machine '${HOST}))

(define %home
  (base-home-environment %machine
                         #:services (append (desktop-services %machine)
                                            (secrets-services %machine))))

%home
EOF
}

function main {
    if [[ $# -ne 1 || "$1" == -* ]]; then
        usage >&2
        exit 1
    fi

    HOST="$1"
    readonly HOST
    local dir="${REPO}/hosts/${HOST}" machines="${REPO}/common/machines.scm"
    local default="        (machine (name 'default))))"

    valid_hostname "${HOST}" || die "Invalid hostname: ${HOST}"
    [[ ! -e "${dir}" ]] || die "hosts/${HOST} already exists"
    grep -qF "(name '${HOST})" "${machines}" && die "${HOST} is already in common/machines.scm"
    grep -qxF "${default}" "${machines}" || die "Found no default machine in common/machines.scm"

    local sops=(sops)
    command -v sops >/dev/null || sops=(guix shell sops -- sops)

    TMP="$(mktemp -d)"
    trap 'rm -rf "${TMP}"' EXIT

    info "Generating the SSH key of ${HOST} ..."
    ssh-keygen -q -t ed25519 -N "" -C "${USER}@${HOST}" -f "${TMP}/id_ed25519"
    {
        echo "ssh: |"
        sed 's/^/    /' "${TMP}/id_ed25519"
    } >"${TMP}/secrets.yaml"
    (cd "${REPO}" &&
         "${sops[@]}" encrypt --filename-override "hosts/${HOST}/secrets.yaml" \
         "${TMP}/secrets.yaml" >"${TMP}/secrets.enc.yaml")

    info "Writing hosts/${HOST} ..."
    mkdir -p "${dir}"
    cp "${TMP}/id_ed25519.pub" "${dir}/ssh.pub"
    cp "${TMP}/secrets.enc.yaml" "${dir}/secrets.yaml"
    write_system "${dir}/system.scm"
    write_home "${dir}/home.scm"
    write_hardware "${dir}/hardware.scm" "${HOST}" \
        "00000000-0000-0000-0000-000000000000" "0000-0000"

    sed -i "s/^${default//\//\\/}\$/        (machine (name '${HOST}))\n&/" "${machines}"

    info "Done. Adjust the machine in common/machines.scm."
}

main "$@"
