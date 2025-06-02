#!/bin/bash

set -eu
set -o pipefail


################################################################################

function choose-secret {
    lpass ls --format="%ag/%an" | grep -Ev '/$' | fzf
}

function show {
    if [ "${OPT_SHOW}" = true ]; then
        lpass show "${@}"
    else
        lpass show -c "${@}"
    fi
}

function usage {
    cat <<EOM
Usage: $(basename "${0}") [-h | --help]

  -h, --help    Show this help message.
  -u, --user    Copy username.
  -p, --pass    Copy password.
  -c, --clear   Clear clip board.
  -s, --show    Show instead of copy to clipboard.

EOM
}

function parse-args {
    local o name opts long

    name="$(basename "${0}")"
    opts="hupcs"
    long="help,user,pass,clear,show"
    o="$(getopt -o "${opts}" -l "${long}" -n "${name}" -- "${@}")"
    eval set -- "${o}"

    OPT_USER=false
    OPT_PASS=false
    OPT_CLEAR=false
    OPT_SHOW=false

    ARG_SECRET=

    while true; do
        case "${1}" in
            -u | --user)  shift ; OPT_USER=true  ;;
            -p | --pass)  shift ; OPT_PASS=true  ;;
            -c | --clear) shift ; OPT_CLEAR=true ;;
            -s | --show)  shift ; OPT_SHOW=true ;;
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
    export OPT_SHOW
    export ARG_SECRET
}

function main {
    parse-args "${@}"

    if [ "${OPT_USER}" = true ]; then
        show --user "${ARG_SECRET}"
        if [ "${OPT_PASS}" = true ] || [ "${OPT_CLEAR}" = true ]; then
            read -rp "Copied username …"
        fi
    fi

    if [ "${OPT_PASS}" = true ]; then
        show --password "${ARG_SECRET}"
        if [ "${OPT_CLEAR}" = true ]; then
            read -rp "Copied password …"
            wl-copy -c
        fi
    fi

}

main "${@}"; exit
