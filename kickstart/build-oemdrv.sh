#!/usr/bin/env bash
# Build oemdrv.iso — a tiny ISO whose volume label is OEMDRV and whose only
# content is ks.cfg. Anaconda auto-detects a volume with this label and runs
# the kickstart with zero keyboard input. Attach it to each UTM VM as a
# second CD drive alongside the Fedora Server installer ISO.
#
# Runs natively on macOS (hdiutil) — no Linux toolchain needed.
# The SSH public key is injected here at build time.
set -euo pipefail
cd "$(dirname "$0")"

PUBKEY_FILE="${PUBKEY_FILE:-$HOME/.ssh/kubeadm-lab_ed25519.pub}"
if [[ ! -f "$PUBKEY_FILE" ]]; then
  cat >&2 <<EOF
error: $PUBKEY_FILE not found.
Generate the lab keypair first:
  ssh-keygen -t ed25519 -C kubeadm-lab -N '' -f ~/.ssh/kubeadm-lab_ed25519
or point PUBKEY_FILE at an existing public key.
EOF
  exit 1
fi
pubkey=$(<"$PUBKEY_FILE")

staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT
sed "s|@SSH_PUBKEY@|${pubkey}|" ks.cfg > "$staging/ks.cfg"
grep -q 'ssh-' "$staging/ks.cfg" || { echo "error: key injection failed" >&2; exit 1; }

rm -f oemdrv.iso
hdiutil makehybrid -iso -joliet -default-volume-name OEMDRV -o oemdrv.iso "$staging"
echo "Built $(pwd)/oemdrv.iso with key from $PUBKEY_FILE"
