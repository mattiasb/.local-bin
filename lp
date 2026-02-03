#!/bin/bash

set -euo pipefail


################################################################################

# shellcheck disable=SC2329
function debug {
    if [ -v DEBUG ]; then
        echo "${FUNCNAME[1]:+${FUNCNAME[1]}: }${*}" >/dev/stderr
    fi
}

function error {
    echo "ERROR: ${*}" >/dev/stderr
}

function error-usage {
    error "${*}"
    echo
    usage
    return 2
}

################################################################################

function choose-secret {
    lpass ls --format="%ag/%an" | grep -Ev '/$' | fzf
}

function show {
    local secret value plain
    local -a fields

    plain="${1}"
    secret="${2}"
    fields=( "${@:3}" )

    for field in "${fields[@]}"; do
        value="$(lpass show "--${field}" "${secret}")"
        if [ "${plain}" = false  ]; then
            echo -n "${field^}: "
        fi
        echo "${value}"
    done
}

function copy {
    local secret
    local -a fields

    secret="${1}"
    fields=( "${@:2}" )

    for field in "${fields[@]}"; do
        lpass show --clip "--${field}" "${secret}"
        read -rp "Copied ${field} …"
    done
}

################################################################################

function usage {
    cat <<EOM
Usage: $(basename "${0}") [-h | --help] <copy|show> [FIELD] [SECRET]

  -h, --help         Show this help message.
  -p, --plain        Don't show field name prefix for the show command.

Where

  FIELD    —  Either url, user[name], pass[word], user-pass or all.
  SECRET   —  Name of secret.
EOM
}

function main {
    local o name opts long
    local cmd field secret plain
    local -a fields=()

    name="$(basename "${0}")"
    opts="h,p"
    long="help,plain"
    o="$(getopt -o "${opts}" -l "${long}" -n "${name}" -- "${@}")"
    eval set -- "${o}"

    plain=false
    while true; do
        case "${1}" in
            -h | --help)  usage
                          exit
                          ;;
            -p | --plain) plain=true
                          shift
                          ;;
            -- )          shift
                          break
                          ;;
            * ) break                                                         ;;
        esac
    done

    cmd="${1:-}"
    case "${cmd}" in
        copy|show)                                                            ;;
        '') error-usage "Missing command"                                     ;;
        *)  error-usage "Unknown command '${cmd}'"                            ;;
    esac

    field="${2:-}"
    case "${field}" in
        user|username) fields=(username)                                      ;;
        pass|password) fields=(password)                                      ;;
        user-pass)     fields=(username password)                             ;;
        all)           fields=(url username password)                         ;;
        '')            fields=(username password)                             ;;
        *)  error-usage "Unknown field '${field}'"                            ;;
    esac
    unset field

    secret="${3:-$(choose-secret)}"

    trap 'wl-copy -c' EXIT

    case "${cmd}" in
        show) show "${plain}" "${secret}" "${fields[@]}"                      ;;
        copy) copy            "${secret}" "${fields[@]}"                      ;;
        *)    error-usage "Unknown command '${cmd}'"                          ;;
    esac
}

main "${@}"; exit
