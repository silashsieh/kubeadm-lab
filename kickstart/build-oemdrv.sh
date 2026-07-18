#!/usr/bin/env bash
# Build oemdrv.iso — a tiny ISO whose volume label is OEMDRV and whose only
# content is ks.cfg. Anaconda auto-detects a volume with this label and runs
# the kickstart with zero keyboard input. Attach it to each UTM VM as a second
# CD drive alongside the Fedora Server installer ISO.
#
# Runs natively on macOS (hdiutil) — no Linux toolchain needed.
set -euo pipefail
cd "$(dirname "$0")"

if grep -q 'TODO-PASTE-PUBLIC-KEY' ks.cfg; then
  echo "error: ks.cfg still contains the SSH key placeholder" >&2
  exit 1
fi

staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT
cp ks.cfg "$staging/ks.cfg"

rm -f oemdrv.iso
hdiutil makehybrid -iso -joliet -default-volume-name OEMDRV -o oemdrv.iso "$staging"
echo "Built $(pwd)/oemdrv.iso"
