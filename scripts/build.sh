#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

if (( EUID != 0 )); then
    echo "Run with sudo: sudo ./scripts/build.sh [public-key-file]" >&2
    exit 1
fi

command -v lb >/dev/null || {
    echo "Install live-build first." >&2
    exit 1
}

key=${1:-}
authorized_keys=config/includes.chroot/root/.ssh/authorized_keys

if [[ -n "$key" ]]; then
    [[ -f "$key" ]] || {
        echo "Public key file not found: $key" >&2
        exit 1
    }
    ssh-keygen -l -f "$key" >/dev/null
fi

lb clean --purge

# Remove any key left by a previous build.
rm -f "$authorized_keys"
trap 'rm -f "$authorized_keys"' EXIT

if [[ -n "$key" ]]; then
    install -d -m 700 "$(dirname "$authorized_keys")"
    install -m 600 "$key" "$authorized_keys"
fi


lb config
lb build 2>&1 | tee build.log
output="host-prep-live.iso"
mv -- live-image-amd64.hybrid.iso "$output"
sha256sum "$output" > "$output.sha256"
