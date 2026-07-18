# UTM VM setup (per node, ×5)

Installer: `Fedora-Server-dvd-aarch64-44-1.7.iso` (3.4 GB). Kickstart is
delivered via the tiny `oemdrv.iso` built by `kickstart/build-oemdrv.sh` —
the installer ISO itself is never modified.

1. UTM → New → **Virtualize** → Linux. Boot ISO: the Fedora Server DVD.
2. Hardware: 2 CPU cores, 4096 MB RAM (4 GiB), 25 GB disk.
3. Network: mode **Bridged**, bridged interface = the Mac's Ethernet.
   Note the generated MAC (or set your own) → add the DHCP reservation on
   the router → record both in `docs/network.md`.
4. Add a second **CD/DVD drive** and attach `kickstart/oemdrv.iso`.
5. Boot. Anaconda finds the OEMDRV volume, runs `ks.cfg` unattended,
   reboots into the installed system. Zero keyboard input.
6. After reboot: remove both ISOs from the VM config.
7. From the control Mac: `ssh silas@<reserved-ip>` must work key-only.

When all five respond: `cd ansible && ansible all -m ping`.
