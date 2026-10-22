#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

# Create hosts/HOSTNAME with a new SSH key and add it to common/machines.scm.

set -Eeuo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
readonly REPO

OPTIONS=()

function usage {
    cat <<USAGE
Usage: $(basename "$0") [--no-luks] HOSTNAME

  --no-luks  Do not encrypt the root partition
USAGE
}

function parse_args {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h | --help)
                usage
                exit 0
                ;;
            --no-luks) OPTIONS+=(no-luks) ;;
            -*)
                usage >&2
                exit 1
                ;;
            *) break ;;
        esac
        shift
    done

    if [[ $# -ne 1 ]]; then
        usage >&2
        exit 1
    fi

    HOST="$1"
    valid_hostname "${HOST}" || die "Invalid hostname: ${HOST}"
    readonly HOST OPTIONS
}

function main {
    parse_args "$@"

    local dir="${REPO}/hosts/${HOST}" machines="${REPO}/common/machines.scm"
    local default="          (name 'default)"

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
    (cd "${REPO}" &&
         GUILE_LOAD_PATH="${REPO}" guix repl -- scripts/host.scm generate "${HOST}" "${TMP}" "${OPTIONS[@]}")
    mkdir -p "${dir}"
    cp "${TMP}/id_ed25519.pub" "${dir}/ssh.pub"
    cp "${TMP}/secrets.enc.yaml" "${dir}/secrets.yaml"
    cp "${TMP}"/{system,home,hardware}.scm "${dir}/"

    sed -i -z "s/        (machine\n${default}/        (machine\n          (name '${HOST})\n          (secrets? #t))\n&/" "${machines}"

    info "Done. Adjust the machine in common/machines.scm."
}

main "$@"
