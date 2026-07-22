# Day-2 operations

## Clean shutdown (before closing a Mac)

From `ansible/`:

```sh
ansible workers -b -m community.general.shutdown
ansible control_plane -b -m community.general.shutdown
```

Workers first; clean OS shutdown lets etcd flush its WAL. Expect Ansible to
report the nodes unreachable as they power off — that's success.

Closing only the MacBook (cp1+cp2)? Same module, hosts `k8s-cp1,k8s-cp2` —
but know what it does: etcd falls to 1/3 members → **quorum lost → API down
cluster-wide** until they return. Workloads on the other Mac's workers keep
running headless; they just can't be managed meanwhile.

## Bring-up

Start the VMs in UTM — that's all. Everything is systemd-enabled: kubelet
finds the static-pod manifests, etcd re-forms quorum once 2 of 3 CP nodes
are up, kube-vip re-elects and re-claims the VIP, workers reconnect. Start
the three CP nodes roughly together, workers whenever. Allow 2–3 minutes,
then `kubectl get nodes` from the Mac (`KUBECONFIG=ansible/kubeconfig`).

Clock skew after host sleep is handled automatically now (`makestep 1.0 -1`
in chrony, enforced by the common role).

## Idle QEMU CPU: why control-plane VMs cost ~1 host core

Measured at idle: cp1 fields ~7k interrupts + ~9k context switches/sec
(etcd raft heartbeats, Go runtime timers, watch bookkeeping); a worker ~2k.
On Apple Silicon, QEMU-HVF emulates the ARM GIC **in userspace** — no
in-kernel irqchip like KVM — so every timer tick, IRQ injection, IPI, and
WFI wake round-trips guest → kernel → QEMU process. Tens of µs each ×
thousands/sec × 2 vCPUs ≈ one host core of pure virtualization plumbing,
invisible to guest `top` (it only counts guest-scheduled cycles).

Mitigations: keep UTM display windows closed (SSH only); heaviest cost is
inherent to control-plane nodes; the big lever is rebuilding on UTM's
Apple Virtualization backend (leaner timer/IRQ path) — cheap thanks to the
automation, but not switchable in place.
