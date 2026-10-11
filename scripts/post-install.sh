#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright © 2026 Florian Marrero Liestmann <f.m.liestmann@fx-ttr.de>

set -Eeuo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
readonly SOURCE
readonly TARGET="${HOME}/src/guix-config"

function move_repo {
    [[ "${SOURCE}" != "${TARGET}" ]] || return 0
    [[ ! -e "${TARGET}" ]] || die "${TARGET} already exists"

    info "Moving ${SOURCE} to ${TARGET} ..."
    mkdir -p "$(dirname "${TARGET}")"
    sudo cp -a "${SOURCE}" "${TARGET}"
    sudo chown -R "$(id -u):$(id -g)" "${TARGET}"
    sudo rm -rf "${SOURCE}"
}

function main {
    [[ "${EUID}" -ne 0 ]] || die "Run as your user, not as root"

    move_repo

    info "Reconfiguring the home environment ..."
    make -C "${TARGET}" home

    info "Done. Commit and push hosts/$(hostname)/disk.scm in ${TARGET}:"
    git -C "${TARGET}" status --short
}

main "$@"
