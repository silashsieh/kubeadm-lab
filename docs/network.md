# Network plan

LAN: `192.168.1.0/24` (home router is the DHCP server). Both Macs run UTM
with **bridged** networking, so every VM gets a first-class address on this
subnet and both Macs can SSH to every node.

## Hosts

| Host | Address | Notes |
|---|---|---|
| Mac 1 (M1, 8-core, 16 GB) | 192.168.1.50 | Ansible control node; hosts 2 VMs |
| Mac 2 | TBD | hosts 3 VMs — record model/RAM here |

## Nodes

Fill in MACs after creating the UTM VMs; set the matching DHCP reservation
on the router before first boot. IPs must match `ansible/inventory/hosts.yml`.

| Node | Role | Host Mac | MAC address | Reserved IP |
|---|---|---|---|---|
| k8s-cp1 | control-plane | TBD | TBD | 192.168.1.61 |
| k8s-cp2 | control-plane | TBD | TBD | 192.168.1.62 |
| k8s-cp3 | control-plane | TBD | TBD | 192.168.1.63 |
| k8s-w1 | worker | TBD | TBD | 192.168.1.64 |
| k8s-w2 | worker | TBD | TBD | 192.168.1.65 |

## Control-plane endpoint

`192.168.1.60:6443` — kube-vip VIP, floated across the three control-plane
nodes (ARP mode + leader election). Outside the DHCP pool; nothing else may
use this address.

## Known risks

- **Bridged mode over Wi-Fi is unreliable.** Many APs drop frames from MAC
  addresses that aren't the associated client's, which silently breaks DHCP
  for bridged VMs. Strongly prefer Ethernet on both Macs; verify with a
  single throwaway VM (does it get a DHCP lease?) before building all five.
- **Control-plane placement vs host failure:** with 3 CP nodes on 2 physical
  Macs, some Mac inevitably hosts 2 of them — that Mac going down loses etcd
  quorum. Acceptable for a lab; worth knowing when running failure drills.
- A sleeping laptop takes its VMs down — disable sleep while the cluster is
  supposed to be up (`caffeinate` or Energy settings).
