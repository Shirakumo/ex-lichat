#!/bin/bash
set -uo pipefail

REMOTE="${REMOTE:-lichat@localhost}"
INSTALL_DIR="${INSTALL_DIR:-/home/lichat/}"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source "$SCRIPT_DIR/.install"

function eexit() {
    echo "$(tput setaf 1) ! Error: $(tput sgr 0)" "$@"
    exit 2
}

function list-archives() {
    local -n _archives=$1
    _archives=$(ls "$SCRIPT_DIR"/_build/prod/rel/lichat/releases/*/lichat.tar.gz)
    IFS=$'\n' _archives=($(sort <<<"${_archives[*]}"))
    unset IFS
}

function latest-archive() {
    local archives
    list-archives archives
    echo "${archives[-1]}"
}

function archive-version() {
    tar -xOzf "$1" releases/lichat.rel | sed -nr 's/.*"lichat","([^"]+)".*/\1/p'
}

function version-archive() {
    echo "$SCRIPT_DIR/_build/prod/rel/lichat/releases/$1/lichat.tar.gz"
}

function upload-archive() {
    local archive="$1"
    local target="${2:-/tmp/$(basename "$archive")}"
    scp "$archive" "$REMOTE:$target" 1>&2 \
        || eexit "Failed to copy $archive to remote: $REMOTE:$target"
    echo "$target"
}

function on-remote() {
    ssh -o LogLevel=QUIET "$REMOTE" -t "$@" 1>&2 \
        || eexit "Failed to execute on remote: $@"
}

function extract-remote() {
    local archive="$1"
    local target="${2:-$INSTALL_DIR}"
    local component="${3:-}"
    on-remote tar -xvzf "$archive" "$component" -C "$target"
    on-remote chown -R lichat:lichat "$target"
}

function install-fresh() {
    local archive="${1:-$(latest-archive)}"
    local remote="$(upload-archive "$archive")"
    extract-remote "$remote"
    on-remote mkdir -p "$INSTALL_DIR/releases"
}

function setup-systemd() {
    local base_copy="${1:-$INSTALL_DIR/lichat.service}"
    local service_file="${2:-/etc/systemd/system/lichat.service}"
    on-remote rm "$service_file"
    on-remote ln -s "$base_copy" "$service_file"
    on-remote systemctl --now enable "$(basename "$service_file")"
}

function install-upgrade() {
    local archive="${1:-$(latest-archive)}"
    local version="$(archive-version "$archive")"
    local remote="$(upload-archive "$archive")"
    extract-remote "$remote" "$INSTALL_DIR" "releases/$version"
    on-remote "$INSTALL_DIR/bin/lichat" upgrade "$version"
}

function build-fresh() {
    MIX_ENV=prod mix distillery.release > /dev/null
    echo "$(latest-archive)"
}

function build-upgrade() {
    MIX_ENV=prod mix distillery.release --upgrade > /dev/null
    echo "$(latest-archive)"
}

function install() {
    local archive="$(build-fresh)"
    install-fresh "$archive"
    setup-systemd
}

function upgrade() {
    local archive="$(build-upgrade)"
    install-upgrade "$archive"
}

function main() {
    local positional_args=()
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -*|--*)
                echo "Unknown option $1"
                exit 1
                ;;
            *)
                positional_args+=("$1") # save positional arg
                shift # past argument
                ;;
        esac
    done

    set -- "${positional_args[@]}" # restore positional parameters
    case "${1:-help}" in
        install) install ;;
        upgrade) upgrade ;;
        build) build-fresh ;;
        service) on-remote systemctl "$2" lichat.service ;;
        list) echo "$(latest-archive)" ;;
        help)
            cat << EOF
Lichat Elixir Installation Manager

This is a small script to more easily manage a remote Lichat server
installation. It requires the server to be on a Linux box and be
managed by systemd.

Available commands:
  install     --- Install the server fresh. This also sets up
                  a systemd service on the remote
  upgrade     --- Upgrade the server to the latest version
  build       --- Build a fresh install package
  service     --- Manage the systemd service
    action      --- The action to perform
  list        --- List available archives
  help        --- Show this help

Relies on the following envvars:
  REMOTE      --- The SSH host to connect to. Note that the user must
                  have access to systemd to manage the services
    [$REMOTE]
  INSTALL_DIR --- The directory on the remote where the installation
                  resides.
    [$INSTALL_DIR]

You may persist the envvars in a .install file next to this
script. The file is evaluated when this script is run.
EOF
            ;;
        *)
            echo "Unknown command $1"
            exit 1
            ;;
    esac
}

main "$@"
