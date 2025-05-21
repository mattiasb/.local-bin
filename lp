#!/bin/bash

set -eu
set -o pipefail


################################################################################

function error {
    echo "ERROR: ${*}" >/dev/stderr
}

function choose-secret {
    lpass ls --format="%ag/%an" | grep -Ev '/$' | fzf
}

function usage {
    cat <<EOM
Usage: $(basename "${0}") [-h | --help]

  -h, --help    Show this help message.
  -u, --user    Copy username.
  -p, --pass    Copy password.
  -c, --clear   Clear clip board.

EOM
}

function parse-args {
    local o name opts long

    name="$(basename "${0}")"
    opts="hupc"
    long="help,user,pass,clear"
    o="$(getopt -o "${opts}" -l "${long}" -n "${name}" -- "${@}")"
    eval set -- "${o}"

    OPT_USER=false
    OPT_PASS=false
    OPT_CLEAR=false

    ARG_SECRET=

    while true; do
        case "${1}" in
            -u | --user)  shift ; OPT_USER=true  ;;
            -p | --pass)  shift ; OPT_PASS=true  ;;
            -c | --clear) shift ; OPT_CLEAR=true ;;
            -h | --help)  usage ; exit           ;;
            -- )          shift ; break          ;;
            * ) break ;;
        esac
    done

    if [ "${OPT_USER}" = false ] && [ "${OPT_PASS}" = false ]; then
        OPT_PASS=true
    fi

    if [ "${#}" -gt 0 ]; then
        ARG_SECRET="${1}"
    else
        ARG_SECRET="$(choose-secret)"
    fi

    export OPT_USER
    export OPT_PASS
    export OPT_CLEAR
    export ARG_SECRET
}

function main {
    parse-args "${@}"

    if [ "${OPT_USER}" = true ]; then
        lpass show -c --user "${ARG_SECRET}"
        if [ "${OPT_PASS}" = true ] || [ "${OPT_CLEAR}" = true ]; then
            read -rp "Copied username …"
        fi
    fi

    if [ "${OPT_PASS}" = true ]; then
        lpass show -c --password "${ARG_SECRET}"
        if [ "${OPT_CLEAR}" = true ]; then
            read -rp "Copied password …"
            wl-copy -c
        fi
    fi

}

main "${@}"; exit
