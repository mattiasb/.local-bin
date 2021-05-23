#!/bin/bash

set -e

################################################################################

function error {
    echo -e "ERROR: ${*}" >&2
}

function debug {
    if [ -v DEBUG ]; then
        echo "${@}"
    fi
}

function confirm {
    read -p "${*} [Y/n] " -n 1 -r -s
    echo
    [[ ! $REPLY =~ ^[Nn]$ ]] && return 0 || return 1
}

function commands {
    for cmd in "${@}"; do
        command -v "${cmd}" > /dev/null || return 1
    done
}

################################################################################

function usage {
    echo "Usage: $(basename "${0}") [--help] [MANIFEST] <COMMAND>"
}

function full-usage {
    usage
    cat <<EOM

Options:
  -h, --help       Show this help text.

Where MANIFEST is a proper flatpak-builder manifest. This is found using
heuristics if not provided.

Where COMMAND is one of:
  build     - Builds all dependencies and finally the application itself.
  shell     - Starts a build shell. Useful for testing.
  run       - Runs the main command of the manifest file (args are passed on)
  clean     - Removes the build cache under ${XDG_CACHE_HOME:-$HOME/.cache}/fp/
  manifest  - Prints the manifest file found by heuristics
EOM
}

################################################################################

function build-deps {
    module="$(yaml2json "${MANIFEST}" | jq -r .modules[-1].name)"

    flatpak-builder --disable-updates                                          \
                    --ccache                                                   \
                    --force-clean                                              \
                    --stop-at="${module}"                                      \
                    "${FLATPAK_DIR}"                                           \
                    "${MANIFEST}"
}

function build-cmd {
    debug
    debug "[${*}]"
    debug
    flatpak-builder --run "${FLATPAK_DIR}" "${MANIFEST}" "${@}"
}

function build {
    local buildsystem config_opts

    buildsystem="$(yaml2json "${MANIFEST}"                                     \
                  | jq -r '.modules[-1] | .buildsystem // "build-api"'         \
                  )"
    config_opts="$( yaml2json "${MANIFEST}"                                    \
                  | jq -r '.modules[-1] | ."config-opts" // [] | join("\n")'   \
                  )"

    case "${buildsystem}" in
        cmake-ninja)
            build-cmd cmake                                                    \
                      -B"${BUILD_DIR}"                                         \
                      -GNinja                                                  \
                      -DCMAKE_INSTALL_PREFIX=/app                              \
                      ${config_opts:+"${config_opts}"}
            build-cmd cmake --build "${BUILD_DIR}"
            build-cmd cmake --install "${BUILD_DIR}"
            return
            ;;
        meson)
            if [ ! -d "${BUILD_DIR}/meson-info" ]; then
                build-cmd mkdir -p "${BUILD_DIR}"
                build-cmd meson setup --prefix /app                            \
                          ${config_opts:+"${config_opts}"}                     \
                          "${BUILD_DIR}"
            fi
            build-cmd meson compile -C "${BUILD_DIR}"
            build-cmd meson install -C "${BUILD_DIR}"
            return
            ;;
        *)
            echo Unsupported build-system! >&2
            exit 4
    esac
}

function run {
    local command

    command="$(yaml2json "${MANIFEST}" | jq -r .command)"

    build-cmd "${command}" "${@}"
}

function find-manifest {
    local candidates

    for ext in yaml yml json; do
        candidates="$(find . -maxdepth 1 -name "*.*.${ext}")"
        for candidate in ${candidates}; do
            app_id="$(yaml2json "${candidate}" | jq -r '."app-id"')"
            if proper-manifest "${candidate}"; then
                realpath "${candidate}"
                return
            fi
        done
    done

    return 4
}

function proper-manifest {
    local manifest

    manifest="${1}"

    app_id="$(yaml2json "${manifest}" | jq -r '."app-id"')"
    test "${app_id}" = "$(basename "${manifest%.*}")"
}

function shell-rc {
    cat <<EORC
PROMPT_DIRTRIM=3
PS1="[📦 \$FLATPAK_ID] \w \$ "
alias ll='ls -l --color=auto'
alias l.='ls -d .* --color=auto'
alias ls='ls --color=auto'
EORC
}

function completion {
    local completion

    completion="$HOME/.local/share/bash-completion/completions/fp"

    echo "# To install bash completion, run:" >&2
    echo "# $ mkdir -p $(dirname "${completion}")" >&2
    echo "# $ $(basename "${0}") completion > ${completion}" >&2
    echo >&2
    cat <<EOF
# fp bash completion
function _complete-fp {
    local cur=\${COMP_WORDS[COMP_CWORD]}

    mapfile -t COMPREPLY < <(compgen -f -X '!*.@(yaml|yml|json)' -- "\$cur" )
}
complete -o filenames -F _complete-fp fp
EOF
}

################################################################################

if ! commands yaml2json jq ; then
    error "This script depends on jq and python-remarshal\n"
    echo "To install jq run something like this:"
    echo "  $ <dnf|apt> install jq"
    echo
    echo "To install remarshal run:"
    echo "  $ pip install --user remarshal"
    exit 3
fi

if [[ " ${*} " == *" -h "* ]]; then
    usage
    exit 0
fi

if [[ " ${*} " == *" --help "* ]]; then
    full-usage
    exit 0
fi

if [ "${#}" -lt 1 ]; then
    error "No command!"
    usage
    exit 2
fi

case "${1}" in
    completion)
        COMMAND="${1}"
        # No manifest needed when just printing out the completion code
        MANIFEST=""
        ;;
    build|shell|run|clean|manifest)
        COMMAND="${1}"
        MANIFEST="$(find-manifest)"
        ;;
    *)
        if ! proper-manifest "${1}"; then
            error "Not a valid flatpak-builder manifest!"
            exit 5
        fi
        MANIFEST="$(realpath "${1}")"
        shift
        COMMAND="${1}"
        ;;
esac

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/fp/$(dirname "${MANIFEST}")"
FLATPAK_DIR="${CACHE_DIR}/flatpak"
BUILD_DIR="${CACHE_DIR}/build"

case "${COMMAND}" in
    build)
        build-deps
        build
        ;;
    shell)
        build-cmd bash --noprofile --rcfile <(shell-rc)
        ;;
    run)
        shift
        run "${@}"
        ;;
    clean)
        confirm "Remove ${CACHE_DIR}" &&
            rm -rf "${CACHE_DIR}"
        ;;
    manifest)
        find-manifest
        ;;
    completion)
        completion
        ;;
    *)
        usage
        exit 2
        ;;
esac
