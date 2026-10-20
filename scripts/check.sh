#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
sh -n auto/config config/hooks/live/010-services.hook.chroot
bash -n scripts/build.sh scripts/check.sh
[[ -s config/package-lists/host-prep.list.chroot ]]
[[ -s config/includes.chroot/etc/systemd/network/20-wired.network ]]
echo "Source checks passed. ISO build and boot tests are still required."
