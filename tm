#!/bin/bash

set -euo pipefail


################################################################################

function fzf {
    command fzf --height "~100%"
}

function tm-has-session {
    local session

    session="${1:-}"

    tmux has-session ${session:+-t "${session}"} 2>/dev/null
}

function tm-sessions {
    if tm-has-session; then
        tmux list-sessions -F "#{session_name}"
    fi
}

function tm-ensure-session {
    local session

    session="${1}"

    if ! tm-has-session "${session}"; then
        tmux  new-session -ds "${session}"
    fi
}

function tm-switch {
    local session

    session="${1}"

    if [ -n "${TMUX:-}" ]; then
        tmux switch-client  -t "${session}"
    else
        tmux attach-session -t "${session}"
    fi
}

function main {
    local session
    local -a sessions=()

    session="${1:-}"

    if [ -z "${session}"  ]; then
        mapfile -t sessions < <(tm-sessions); wait $!
        case "${#sessions[@]}" in
            0) session=default                                                ;;
            1) session="${sessions[0]}"                                       ;;
            *) session="$(printf '%s\n' "${sessions[@]}" | fzf)"              ;;
        esac
    fi

    tm-ensure-session "${session}"
    tm-switch         "${session}"
}

main "${@}"; exit
