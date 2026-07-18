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

## Decisions so far

- Nodes: 5 × UTM VMs (2 CPU / 4 GB / 25 GB, aarch64) across two Macs, bridged
  onto 192.168.1.0/24; Fedora Server 44, identity via DHCP MAC reservations
- Topology: 3 control-plane (stacked etcd) + 2 workers
- Kubernetes: pinned to v1.36 (latest stable minor as of 2026-07)
- Kickstart stays thin (user/SSH/python3 only); all convergence in Ansible

## Open decisions

- CNI: Calico vs Flannel vs Cilium (placeholder: Calico)
- Control-plane endpoint: kube-vip VIP vs external load balancer

## Status

Design phase — skeleton laid out, roles are TODO stubs, implementation not
started.

## License

[MIT](LICENSE)
