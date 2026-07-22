# 2026-07-22 — First converge: three real bugs between "playbook written" and "5 nodes Ready"

Four runs to green. Every failure was a legitimate distributed-systems lesson,
none was hypothetical. Kept here verbatim as interview material.

## Run 1 — missing OCI runtime, diagnosed three layers down

**Symptom:** joins failed with `dial tcp 192.168.1.60:6443: no route to host`
— the VIP simply didn't exist.

**Chain:** VIP absent → kube-vip pod never started → *no* pod could start,
including etcd and kube-apiserver → `journalctl -u kubelet` showed
`CreatePodSandbox ... exec: "runc": executable file not found in $PATH`.
Fedora's `containerd` rpm does not hard-require an OCI runtime.

**The trap:** `kubeadm init` had written certs and manifests, then timed out
waiting for a control plane that could never start — leaving *partial* state.
The playbook's `creates: kubelet.conf` idempotency guard would have skipped
init on rerun and hidden the problem. `kubeadm reset -f` first, then rerun.

**Layer lesson:** symptom at the top (routing), cause three layers down
(kubelet → CRI/containerd → OCI/runc). Also: install `cri-tools` day one;
debugging without `crictl` is miserable.

## Run 2 — the certificate-key race (playbook bug, found by Ansible's execution model)

**Symptom:** cp2's control-plane join: `error downloading certs: cipher:
message authentication failed`.

**Cause:** each joining CP ran its own delegated
`kubeadm init phase upload-certs`. Every upload **re-encrypts the
kubeadm-certs Secret with a fresh key**. Ansible's linear strategy runs
task-by-task across hosts, so both uploads happened back-to-back before
either join — cp3's upload invalidated cp2's key. Only the last uploader
could ever join.

**Fix:** `serial: 1` on the control-plane play (the Kubespray approach):
each node runs the *whole* role — token, upload, join — before the next
starts.

## Runs 2–3 — clock skew masquerading as an etcd failure

**Symptom (twice):** cp3's join died at
`check-etcd: error syncing endpoints with etcd: context deadline exceeded`,
after exactly 2 minutes (kubeadm's etcd budget). Raw TCP to `:2379` was fine.

**False lead:** `curl -k https://…:2379/health` returned rc=56 from cp3 —
looked like unreachability, but a *healthy* member returned the same: etcd
requires client certs, so a certless TLS handshake is always reset. Test was
invalid.

**Break in the case:** Node `creationTimestamp`s didn't reconcile with wall
clock, and log timestamps implied a phantom 12-minute gap between tasks.
`chronyc tracking`: **cp1/cp2 were 660 s slow — and chrony knew** but
wouldn't fix it, because Fedora's default `makestep 1.0 3` only steps the
clock in the first three updates after boot.

**Root cause:** the host MacBook slept; QEMU guests' clocks froze and woke
11 minutes behind. kubeadm generates join certs with `NotBefore = now`, so
certs minted on correct-clock cp3 read "not yet valid" to slow-clock etcd on
cp1 — surfacing as a generic timeout. cp2 joined fine because it was
*equally slow* as cp1: consistency mattered, not correctness.

**Fix:** `makestep 1.0 -1` (always step) + chronyd restart, enforced by the
common role. Home-lab clusters on sleeping laptops need this or they will
rot every time the lid closes.

## Runs 1–3 — the worker play that never ran

The `Join workers` play executed **zero times** in the first three runs:
when *every* host in a play fails, Ansible aborts the entire playbook. The
per-host recap (`ok=20 changed=19 failed=0`) was entirely the "Prepare all
nodes" play and was misread as evidence the workers had joined.

**Lesson:** verify against the system (`kubectl get nodes`), never against
the tool's summary counters. Recap numbers answer "what did Ansible do",
not "what state is the cluster in".

## Run 4 — green

All five nodes joined; 3-member etcd (no learners); workers `Ready` after
calico-node rollout. Total wall time from first attempt to green: ~50 min,
all of it diagnostic value.
