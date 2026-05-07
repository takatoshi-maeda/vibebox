#!/bin/bash

set -u

REMOTE_USER="${1:-vibebox}"
CONTAINER_NAME="${2:-}"
WORKSPACE_DIR="$(pwd)"
AUTHORIZED_KEYS_FILE="$WORKSPACE_DIR/.devcontainer/.vibebox-authorized_keys"

setup_authorized_keys() {
    mkdir -p "$WORKSPACE_DIR/.devcontainer"

    if ls "${HOME}/.ssh/"*.pub >/dev/null 2>&1; then
        cat "${HOME}/.ssh/"*.pub > "$AUTHORIZED_KEYS_FILE"
        chmod 600 "$AUTHORIZED_KEYS_FILE"
    else
        : > "$AUTHORIZED_KEYS_FILE"
        chmod 600 "$AUTHORIZED_KEYS_FILE"
        echo "Warning: no SSH public keys found in ~/.ssh/*.pub; SSH login to the vibebox container will fail until a public key is added." >&2
    fi
}

setup_ssh_config() {
    if [[ -z "$CONTAINER_NAME" ]]; then
        echo "Skipping SSH config setup: container name is not set." >&2
        return 0
    fi

    local ssh_dir="$HOME/.ssh"
    local ssh_config="$ssh_dir/config"
    local begin_marker="# >>> vibebox $CONTAINER_NAME"
    local end_marker="# <<< vibebox $CONTAINER_NAME"
    local temp_file
    temp_file=$(mktemp)

    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir" 2>/dev/null || true
    touch "$ssh_config"
    chmod 600 "$ssh_config" 2>/dev/null || true

    awk -v begin="$begin_marker" -v end="$end_marker" '
        $0 == begin { skip = 1; next }
        $0 == end { skip = 0; next }
        !skip { print }
    ' "$ssh_config" > "$temp_file"

    {
        if [[ -s "$temp_file" ]] && [[ "$(tail -c 1 "$temp_file")" != "" ]]; then
            printf '\n'
        fi
        cat <<EOF
$begin_marker
Host $CONTAINER_NAME $CONTAINER_NAME.orb.local
    HostName $CONTAINER_NAME.orb.local
    User $REMOTE_USER
    Port 22
    UserKnownHostsFile /dev/null
    StrictHostKeyChecking no
$end_marker
EOF
    } >> "$temp_file"

    mv "$temp_file" "$ssh_config"
    chmod 600 "$ssh_config" 2>/dev/null || true

    echo "SSH接続設定を更新しました: $ssh_config"
    echo "  ssh $CONTAINER_NAME"
}

setup_authorized_keys
setup_ssh_config
