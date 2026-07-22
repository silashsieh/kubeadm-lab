# Runbook: cluster bring-up from scratch

Two paths. Path B (reuse installed OS) is 10× faster than Path A and is the
normal way to rebuild after a destructive drill — reach for Path A only when
the OS itself is suspect or the VMs don't exist yet.

## One-time prerequisites (control Mac)

```sh
uv tool install ansible-core --with ansible   # ansible-playbook + collections
brew install kubectl
ssh-keygen -t ed25519 -C kubeadm-lab -N '' -f ~/.ssh/kubeadm-lab_ed25519
```

Router: DHCP reservations for the five VM MACs → 192.168.1.61–65
(`docs/network.md` is the ledger; keep it current). The VIP 192.168.1.60
must stay outside the DHCP pool.

## Path A — brand-new nodes (no OS, or reinstall wanted)

1. `kickstart/build-oemdrv.sh` → `kickstart/oemdrv.iso` (injects your pubkey;
   rebuild whenever the key or ks.cfg changes).
2. Create/replace the five UTM VMs per `docs/utm-setup.md` — 2 CPU / 4 GiB /
   25 GB, bridged, note each MAC, attach Fedora installer ISO + oemdrv.iso.
3. Boot. Installs are unattended (~5 min each, parallel is fine); VMs reboot
   into the installed OS. Detach both ISOs afterwards — a VM that boots the
   installer again will happily re-kickstart itself and wipe the node.
4. Sanity: `cd ansible && ansible all -m ping` — all five must answer.
5. `ansible-playbook site.yml` (~10–15 min: packages, serial control-plane
   bootstrap, Calico, workers).
6. Verify (below).

## Path B — rebuild the cluster, keep the OS

Wipes Kubernetes state on every node, then converges from zero. Package
installs are already done, so this is ~5–10 min total.

```sh
cd ansible
ansible all -b -m command -a "kubeadm reset -f"
ansible-playbook site.yml
```

`kubeadm reset` leaves some iptables/CNI debris behind; the playbook
tolerates it, but if pod networking acts haunted after a rebuild, reboot the
nodes once (`ansible all -b -m reboot`) and rerun the playbook — it's
idempotent, rerunning is always safe.

## Verify

```sh
export KUBECONFIG=ansible/kubeconfig       # fetched fresh by the playbook
kubectl get nodes                          # 5 nodes, Ready within ~3 min
kubectl get pods -A --field-selector=status.phase!=Running   # want: empty
kubectl create deploy smoke --image=nginx --replicas=2 && \
  kubectl rollout status deploy/smoke && kubectl delete deploy smoke
```

3 CP nodes Ready + 2 workers Ready + clean pod list + a deployment that
rolls out on the workers = the cluster is real.

## When it fails

Every failure so far has been worth reading about once:
`docs/experiments/2026-07-22-first-converge.md` (missing runc, upload-certs
key race, host-sleep clock skew). Debug order that has paid off:
`journalctl -u kubelet` on the sick node → `crictl ps -a` → clocks
(`chronyc tracking`) → then the network.
