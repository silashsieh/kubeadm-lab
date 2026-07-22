# kubeadm-lab

A five-node Kubernetes home lab, provisioned the way on-prem fleets are:

- **Kickstart** installs a minimal Fedora Server on each node — user, SSH key,
  and Python only. Node identity (IP, hostname) stays out of the image and
  comes from DHCP MAC reservations and the Ansible inventory.
- **Ansible** does everything else from a macOS control node: OS prep
  (zram swap off, firewalld, sysctls), containerd, and a kubeadm cluster with
  a 3-node HA control plane (kube-vip) plus 2 workers.

The OS layer is intentionally thin and swappable — the same playbooks should
converge Fedora, Rocky, or Debian nodes.

## Layout

```
kickstart/          generic ks.cfg + build-oemdrv.sh (macOS hdiutil → OEMDRV iso)
ansible/            inventory, group_vars, site.yml, roles (stubs, TODO-annotated)
docs/               network plan, UTM setup steps, experiment log
```

## Decisions

- Nodes: 5 × UTM VMs (2 CPU / 4 GB / 25 GB, aarch64) across two Macs, bridged
  onto 192.168.1.0/24; Fedora Server 44, identity via DHCP MAC reservations
  (nodes 192.168.1.61–65)
- Topology: 3 control-plane (stacked etcd) + 2 workers
- Kubernetes: pinned to v1.36 (latest stable minor as of 2026-07)
- CNI: Calico v3.32 in BGP / no-encapsulation mode (flat L2 subnet)
- API endpoint: kube-vip v1.2 static pods, ARP-mode VIP at 192.168.1.60:6443
- Kickstart stays thin (user/SSH/python3 only); all convergence in Ansible

## Quickstart

One-time on the control Mac:

```sh
uv tool install ansible        # or: brew install ansible
ssh-keygen -t ed25519 -C kubeadm-lab -N '' -f ~/.ssh/kubeadm-lab_ed25519
```

Then:

1. Router: add DHCP reservations for the five VM MACs → 192.168.1.61–65
   (record MACs in `docs/network.md`)
2. `kickstart/build-oemdrv.sh` → `oemdrv.iso` (injects your SSH pubkey)
3. Create the 5 UTM VMs per `docs/utm-setup.md`, boot — installs are
   unattended
4. `cd ansible && ansible all -m ping` — all five must answer
5. `ansible-playbook site.yml`
6. From the Mac: `KUBECONFIG=ansible/kubeconfig kubectl get nodes`

## Status

**Converged 2026-07-22**: 5 nodes, 3-member etcd HA control plane behind the
kube-vip VIP, Calico BGP networking. Four runs to green — the three real
bugs hit along the way (missing runc, upload-certs key race, host-sleep
clock skew) are written up in
[docs/experiments/2026-07-22-first-converge.md](docs/experiments/2026-07-22-first-converge.md).

## License

[MIT](LICENSE)
