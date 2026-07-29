#!/bin/bash
# tb-splice.sh — move UTM host-only VM interfaces (vmenetN) into the
# macOS-built Thunderbolt Bridge (bridge0) so the VMs join the TB L2
# segment. Run on EACH Mac, with sudo, AFTER starting its VMs:
#
#   sudo ./scripts/tb-splice.sh
#
# Idempotent — safe to re-run any time; already-spliced interfaces are
# untouched. Must be re-run after every VM (re)start: vmnet creates a
# fresh vmenetN per boot and always parks it in its own host-only bridge.
# Why any of this exists: docs/network.md, "VM attachment: the vmenet
# splice" (vmnet cannot bridge VMs onto Thunderbolt interfaces).
set -euo pipefail

TB_BRIDGE=bridge0
MTU=1500   # vmenet is fixed at 1500; a member's MTU must equal the bridge's

if ! ifconfig "$TB_BRIDGE" >/dev/null 2>&1; then
  echo "error: $TB_BRIDGE not found — is the Thunderbolt Bridge service enabled?" >&2
  exit 1
fi

cur_mtu=$(ifconfig "$TB_BRIDGE" | sed -n '1s/.*mtu \([0-9]*\).*/\1/p')
if [ "$cur_mtu" != "$MTU" ]; then
  echo "setting $TB_BRIDGE mtu: $cur_mtu -> $MTU"
  ifconfig "$TB_BRIDGE" mtu "$MTU"
fi

moved=0
for b in $(ifconfig -a | sed -n 's/^\(bridge[0-9][0-9]*\):.*/\1/p'); do
  if [ "$b" = "$TB_BRIDGE" ]; then
    continue
  fi
  members=$(ifconfig "$b" | awk '/member:/{print $2}')
  # A bridge holding a real enX member is vmnet's MACNAT bridge for
  # Wi-Fi-bridged NICs — its vmenet carries node identity; leave it alone.
  if printf '%s\n' $members | grep -q '^en'; then
    continue
  fi
  for m in $members; do
    case "$m" in
      vmenet*)
        echo "moving $m: $b -> $TB_BRIDGE"
        ifconfig "$b" deletem "$m"
        ifconfig "$m" up
        ifconfig "$TB_BRIDGE" addm "$m"
        moved=$((moved + 1))
        ;;
    esac
  done
done

# Recover vmenets dangling in NO bridge (a previously half-finished
# splice: deletem succeeded, addm failed — seen once when the bridge MTU
# was still 9000). vmnet never leaves its own members dangling, so any
# orphan is a host-only NIC that belongs on the TB bridge.
all_members=$(ifconfig -a | awk '/member:/{print $2}')
for v in $(ifconfig -a | sed -n 's/^\(vmenet[0-9][0-9]*\):.*/\1/p'); do
  if ! printf '%s\n' $all_members | grep -qx "$v"; then
    echo "adopting orphaned $v -> $TB_BRIDGE"
    ifconfig "$v" up
    ifconfig "$TB_BRIDGE" addm "$v"
    moved=$((moved + 1))
  fi
done

echo "done ($moved moved). $TB_BRIDGE members:"
ifconfig "$TB_BRIDGE" | awk '/member:/{print "  " $2}'
