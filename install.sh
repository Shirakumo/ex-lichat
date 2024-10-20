#!/bin/bash
set -uo pipefail

REMOTE="${REMOTE:-lichat@localhost}"
REMOTE_USER="${REMOTE_USER:-lichat}"
INSTALL_DIR="${INSTALL_DIR:-/home/$REMOTE_USER/}"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
VARIANT="${VARIANT:-prod}"

source "$SCRIPT_DIR/.install"

function eexit() {
    echo -e "\n$(tput setaf 1) ! Error: $(tput sgr 0)" "$@" "\n"
    exit 2
}

function log() {
    >&2 echo -e "$(tput setaf 1) ! $(tput sgr 0)" "$@"
}

function on-remote() {
    ssh -o LogLevel=QUIET "$REMOTE" -t "$@" \
        || eexit "Failed to execute on remote: $@"
}

function remote-rpc() {
    on-remote sudo -H -u "$REMOTE_USER" "$INSTALL_DIR/bin/lichat" rpc "$@"
}

function list-archives() {
    local -n _archives=$1
    _archives=$(ls "$SCRIPT_DIR"/_build/$VARIANT/lichat-*.tar.gz)
    IFS=$'\n' _archives=($(sort <<<"${_archives[*]}"))
    unset IFS
}

function latest-archive() {
    local archives
    list-archives archives
    echo "${archives[-1]}"
}

function archive-version() {
    tar -xOzf "$1" releases/start_erl.data | awk '{ print $2 }'
}

function version-archive() {
    echo "$SCRIPT_DIR/_build/$VARIANT/lichat-$1.tar.gz"
}

function remote-version() {
    on-remote cat "$INSTALL_DIR/releases/start_erl.data" | awk '{ print $2 }'
}

function upload-archive() {
    local archive="$1"
    local target="${2:-/tmp/$(basename "$archive")}"
    log "Uploading to $REMOTE:$target"
    scp "$archive" "$REMOTE:$target" 1>&2 \
        || eexit "Failed to copy $archive to remote: $REMOTE:$target"
    echo "$target"
}

function extract-remote() {
    local archive="$1"
    local target="${2:-$INSTALL_DIR}"
    local component="${3:-}"
    log "Extracting to $REMOTE:$target"
    on-remote tar -xzf "$archive" "$component" -C "$target"
    on-remote chown -R "$REMOTE_USER:$REMOTE_USER" "$target"
}

function install-fresh() {
    local archive="${1:-$(latest-archive)}"
    log "Installing $archive"
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
    local remote_ver="$(remote-version)"
    local remote="$(upload-archive "$archive")"
    extract-remote "$remote"
    echo "{\"$remote_ver\",[{\"$version\", []}],[]}." > "$SCRIPT_DIR/lichat.appup"
    log "Please review $SCRIPT_DIR/lichat.appup and hit enter when it is correct to proceed with the update."
    read
    scp "SCRIPT_DIR/lichat.appup" "$REMOTE:$INSTALL_DIR/lib/lichat-$version/ebin/lichat.appup" 1>&2 \
        || eexit "Failed to copy appup to remote"
    remote-rpc ":release_handler.upgrade_script(:lichat '$INSTALL_DIR/lib/lichat-$version/')"
    remote-rpc ":release_handler.upgrade_app(:lichat '$INSTALL_DIR/lib/lichat-$version/')"
}

function build() {
    log "Building current release"
    MIX_ENV=$VARIANT mix release --overwrite --quiet &>> /dev/null \
        || eexit "Build failed!"
    echo "$(latest-archive)"
}

function install() {
    local archive="$(build)"
    install-fresh "$archive"
    setup-systemd
}

function upgrade() {
    local archive="$(build)"
    local version="$(remote-version)"
    [ "$version" = "$(archive-version "$archive")" ] \
       && eexit "Remote is already on version $version"
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
        build) build ;;
        service) on-remote systemctl "$2" lichat.service ;;
        version) remote-version ;;
        list-versions)
            local archives
            list-archives archives
            echo "$(for i in "$archives"; do archive-version "$i"; done)" ;;
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
  version     --- Show the version on the remote
  list-versions  --- List available archives
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
