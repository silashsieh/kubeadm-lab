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

## Status

Design phase — architecture under discussion, implementation not started.

## License

[MIT](LICENSE)
