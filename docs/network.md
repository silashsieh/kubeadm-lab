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

## Service LoadBalancer pool

`192.168.1.70`–`192.168.1.79` — MetalLB (L2/ARP mode) hands these out to
`type: LoadBalancer` services. Like the VIP, this range must stay outside
the router's DHCP pool and has no DHCP reservations; MetalLB answers ARP
for whichever addresses are in use. If the router's DHCP pool overlaps,
shrink it — an overlap fails intermittently (works until the router leases
a colliding address).

## Thunderbolt cluster network

`10.10.0.0/24` — a direct USB4/Thunderbolt cable between the two Macs.
Carries Calico BGP sessions and pod traffic (the Installation CR pins
`nodeAddressAutodetectionV4` to the TB NIC). Exists because **bridged VMs
on Wi-Fi are MAC-NATed**: macOS rewrites every VM's source MAC to the
host's Wi-Fi MAC (802.11 3-address frames can't carry foreign MACs) and
demultiplexes inbound frames by destination IP learned from the VM's own
ARP/DHCP chatter. Routed packets — pod-CIDR addresses the host never saw
the VM ARP for — are silently dropped. GARP-announced VIPs (kube-vip,
MetalLB L2) survive MAC-NAT; Calico's routed pod IPs do not.

SSH, Ansible, and node identity stay on Wi-Fi (192.168.1.x); the guests'
`tb` connection is `never-default`, so the TB subnet never routes out.

| Endpoint | Address |
|---|---|
| Mac 1 — Thunderbolt Bridge (`bridge0`) | 10.10.0.1 |
| Mac 2 — Thunderbolt Bridge (`bridge0`) | 10.10.0.2 |
| k8s-cp1 … k8s-w2 (`enp0s2`, second NIC) | 10.10.0.61 – 10.10.0.65 (mirrors Wi-Fi octet) |

### VM attachment: the vmenet splice

Apple's vmnet framework refuses to bridge VMs onto Thunderbolt interfaces
(`unsupported ifname … expected one of [ en0 ]`), so each VM's second NIC
runs in **Host-Only** mode and its host-side `vmenetN` interface is moved
into the macOS-built Thunderbolt Bridge after every VM boot:

    sudo ./scripts/tb-splice.sh    # on each Mac, after starting its VMs

The script finds every host-only `vmenetN`, moves it into `bridge0`, and
fixes the bridge MTU; it is idempotent and skips the Wi-Fi MACNAT bridge.
Manual equivalent, if ever needed:

    # confirm names first: ifconfig -a | grep -E '^(bridge|vmenet)|member'
    sudo ifconfig bridge101 deletem vmenet1   # vmnet's host-only bridge
    sudo ifconfig bridge0 addm vmenet1        # the Thunderbolt Bridge

Hard-won caveats:

- **Member MTU must equal bridge MTU.** `addm` fails with `Invalid
  argument` otherwise. `vmenet` is always 1500; if `bridge0` came up at
  9000, `sudo ifconfig bridge0 mtu 1500` first (also keeps both Macs'
  bridges consistent).
- **Never add the `enN` TB ports to a bridge yourself.** They are
  Skywalk-backed; the public ioctl fails with `Operation not supported on
  socket`. Only configd can enslave them — let macOS build `bridge0` from
  the "Thunderbolt Bridge" network service and add only `vmenetN`.
- **`vmenetN`/`bridgeN` numbering shifts** across VM restarts — always
  re-check names before splicing.
- **The splice does not survive VM restarts or host reboots.** Stopping a
  VM destroys its `vmenetN` entirely; the next boot creates a fresh one
  back inside the host-only bridge. Re-run `scripts/tb-splice.sh` after
  every VM start. Everything else persists: the Macs' bridge services and
  IPs (configd), the UTM NIC modes, and the guests' nmcli `tb` profiles.
- If configd builds `bridge0` with a TB port missing, stale Skywalk state
  is usually why — reboot the Mac; don't fight it with `ifconfig`.

## Known risks

- **Bridged mode over Wi-Fi is unreliable.** Many APs drop frames from MAC
  addresses that aren't the associated client's, which silently breaks DHCP
  for bridged VMs. macOS works around this with MAC-NAT — which is exactly
  what breaks routed pod traffic (this bit us; see "Thunderbolt cluster
  network" above). Prefer Ethernet, or the TB link for cluster traffic.
- **Control-plane placement vs host failure:** with 3 CP nodes on 2 physical
  Macs, some Mac inevitably hosts 2 of them — that Mac going down loses etcd
  quorum. Acceptable for a lab; worth knowing when running failure drills.
- A sleeping laptop takes its VMs down — disable sleep while the cluster is
  supposed to be up (`caffeinate` or Energy settings).
