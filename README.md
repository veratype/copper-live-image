# Host Prep Live

Minimal Debian 13 (trixie), amd64 live-build source project for remote bare-metal preparation. Boot starts DHCP and root SSH; Ansible remains responsible for inventory, RAID layout and imaging. No disks are wiped, mounted or imaged by project boot scripts.

## Build

Use a Debian 13 amd64 build host or VM with root privileges and working Debian mirror access. Other distributions may ship older live-build releases; a Debian VM avoids that mismatch.

```bash
sudo apt update
sudo apt install --no-install-recommends live-build debootstrap squashfs-tools xorriso isolinux syslinux-common grub-pc-bin grub-efi-amd64-bin mtools dosfstools openssh-client
./scripts/check.sh
# Copy vendor .deb files into config/packages.chroot first.
sudo ./scripts/build.sh "$HOME/.ssh/id_ed25519.pub"
# OR do it without pubkey
sudo ./scripts/build.sh 
```

Output: `live-image-amd64.hybrid.iso` and its SHA-256 file. Build logs are in `build.log`. This archive contains source, not a built ISO. Actual ISO size and hardware compatibility require a real build and boot test. Vendor binaries are not included.

The public key is temporarily injected for the build, then removed from the source tree; it remains inside the ISO. Public keys are not secrets, but they define who has root access. Never supply a private key. Put the source directory in your Git server; generated artifacts and vendor packages are ignored.

## Runtime

All Ethernet interfaces named en* or eth* request IPv4 DHCP. networkd retries DHCP while the system stays available; there is no requirement for a default route, so an isolated provisioning subnet works. On multi-NIC servers each matching interface can obtain a lease and route: narrow the Match section by MACAddress if necessary.

`systemd-resolved` handles DNS. No dhclient, NetworkManager, desktop, installer or cloud-init is added. Python is included for Ansible. Some Ansible modules require extra dependencies: add python3-apt only if using apt modules.

SSH host keys are created at each boot in the writable live overlay. Obtain and verify host fingerprints through a trusted console or provisioning channel; a fresh boot can legitimately change known_hosts. Do not reuse one baked host key across the fleet.

Firmware package selection is a starting point for server NICs, not a guarantee for every adapter. Kernel drivers come from the Debian amd64 kernel; test your Intel/Broadcom/Mellanox NICs and RAID controllers and add missing firmware. Automatic broad firmware inclusion is disabled to control size. There are no bundled GPU drivers or vendor RAID utilities.

## Smoke test

```bash
qemu-system-x86_64 -enable-kvm -m 2048 -smp 2 \
  -cdrom live-image-amd64.hybrid.iso \
  -nic user,hostfwd=tcp:127.0.0.1:2222-:22
ssh -p 2222 -i ~/.ssh/id_ed25519 root@127.0.0.1
```

QEMU user networking requires the host forwarding above; the guest private address is not directly reachable from your host. Test UEFI separately with your distribution's OVMF firmware; the command above tests BIOS. Secure Boot is not validated.

Inside the live system check:

```bash
systemctl --no-pager status systemd-networkd systemd-resolved ssh
ip -br address
ip route
resolvectl status
python3 --version
lsblk
lspci -nnk
```

Then test Ansible:

```bash
ansible all -i '127.0.0.1,' -u root --private-key ~/.ssh/id_ed25519 \
  -e ansible_port=2222 -e ansible_python_interpreter=/usr/bin/python3 -m ping
```

On physical hardware test BIOS/UEFI as applicable, delayed DHCP, NIC firmware, controller visibility, and the correct vendor CLI. Do this before any destructive Ansible tasks.

## PXE

Once the ISO works, its `/live/vmlinuz`, `/live/initrd.img`, and `/live/filesystem.squashfs` can form an HTTP live-boot deployment. PXE initramfs networking happens before networkd starts: networkd retries do not fix an initramfs that cannot fetch its root filesystem during STP convergence. Validate that early network phase separately. This project does not configure a PXE/DHCP server or registration service; inventory can initially come from DHCP leases and Ansible setup facts.

## Reproducibility

Version-controlled configuration makes the recipe repeatable, not byte-identical. Normal Debian mirrors change over time. For strict reproducibility pin a dated snapshot/internal mirror and archive the vendor packages and checksums.

References: https://live-team.pages.debian.net/live-manual/html/live-manual.en.html and https://packages.debian.org/trixie/systemd-resolved
