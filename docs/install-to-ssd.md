# Install the persistent NixOS development environment

This guide describes the manual installation route using the **existing NixOS live installer** as an SSH-accessible
installation environment. The `installed` flake output produces an installed
NixOS system with a persistent root filesystem, user home, Docker storage,
`/workspace`, and the same declarative development toolchain as the live ISO.

No storage device is selected or formatted automatically by this repository.
These instructions assume **UEFI** boot, a single target SSD, and an explicitly
chosen unencrypted ext4 root filesystem. Adjust this design before proceeding
if you need encrypted storage, dual boot, RAID, or an existing partition layout.

Alternatively, build a bootable raw image on GitHub and flash it to an external SSD from your Mac; see [flash the SSD from macOS](flash-ssd-from-mac.md). No live USB or on-device installer is needed with that approach.

## 1. Boot the live USB and identify the target

Connect by SSH to the live system. Verify firmware mode and list disks:

```sh
test -d /sys/firmware/efi && echo UEFI
lsblk -o NAME,PATH,SIZE,MODEL,TRAN,TYPE,FSTYPE,MOUNTPOINTS
ls -l /dev/disk/by-id/
```

**Stop if the target disk cannot be identified confidently.** In particular,
do not format the USB you booted from or a disk containing data you need.

## 2. Prepare partitions (destructive, manual operation)

The installed profile expects exactly these *filesystem labels*:

| Partition | Filesystem | Label | Mount point |
| --- | --- | --- | --- |
| EFI System Partition | FAT32, 1 GiB | `ESP` | `/boot` |
| System partition | ext4, remaining space | `nixos` | `/` |

Example **only for a previously identified, expendable target disk**. Every
`parted` and `mkfs` command below destroys or overwrites on-disk data.

Replace the placeholder with a verified by-id path; there is deliberately no
default and no auto-detection of a target disk.

```sh
DISK=/dev/disk/by-id/REPLACE_WITH_VERIFIED_SSD_ID
test -b "$DISK" || { echo 'Set DISK to an existing block device' >&2; exit 1; }
lsblk -o NAME,SIZE,MODEL,TYPE,MOUNTPOINTS "$DISK"
```

Only after reviewing the device above and deciding to erase it:

```sh
sudo parted --script "$DISK" mklabel gpt
sudo parted --script "$DISK" mkpart ESP fat32 1MiB 1025MiB
sudo parted --script "$DISK" set 1 esp on
sudo parted --script "$DISK" mkpart primary ext4 1025MiB 100%
sudo partprobe "$DISK"

sudo mkfs.fat -F 32 -n ESP "${DISK}-part1"
sudo mkfs.ext4 -L nixos "${DISK}-part2"
```

If the partition symlinks do not exist, inspect `lsblk` and
`/dev/disk/by-id/` rather than guessing device names.

## 3. Mount the target and install

```sh
sudo mount /dev/disk/by-label/nixos /mnt
sudo mkdir -p /mnt/boot
sudo mount -o umask=077 /dev/disk/by-label/ESP /mnt/boot

git clone --branch main --single-branch \
  https://github.com/brackxm/framework-dev-nixos-live.git
cd framework-dev-nixos-live

# Keep the flake and its exact lockfile on the installed filesystem.
sudo mkdir -p /mnt/etc/nixos
sudo cp -a "$PWD" /mnt/etc/nixos/framework-dev-nixos-live

sudo nixos-install --root /mnt \
  --flake /mnt/etc/nixos/framework-dev-nixos-live#installed \
  --no-root-passwd
```

Before reboot, confirm that the intended root and boot partitions are mounted,
the flake source is present under `/mnt/etc/nixos`, and installation finished
without error.

`--no-root-passwd` disables the installer's interactive root-password prompt;
it does not set up password authentication. SSH public-key login is predeclared
for the `nixos` user. That user is granted passwordless sudo, so treat the SSH
private key as an administrative credential and restrict network access.

## Framework Desktop hardware and firmware

The installed profile imports a pinned `nixos-hardware` Framework Desktop
AMD AI Max 300 Series module, for the AMD CPU/GPU defaults, SSD TRIM and
`framework-tool`. The live USB profiles remain generic.

The installed profile also enables `fwupd` for supported BIOS/device updates.
After the installed system boots, check firmware versions and available updates:

```sh
fwupdmgr get-devices
sudo fwupdmgr refresh
fwupdmgr get-updates
```

**Do not start a firmware update without reviewing its release notes, power
requirements and reboot implications.** Apply a chosen update separately with
`sudo fwupdmgr update`; it is not part of disk installation or an automatic
NixOS rebuild.

## 4. Boot and verify

```sh
sudo reboot
```

Remove the live USB or change the boot priority to the installed SSD. Then from
your SSH client:

```sh
ssh dev
findmnt /
findmnt /workspace
df -h / /workspace /var/lib/docker
sudo systemctl status sshd
sudo systemctl status docker
```

`/workspace` is a directory on the persistent root filesystem rather than a
separately mounted tmpfs, so `findmnt /workspace` should report the underlying
root mount.

Once connected, create a test file in `/workspace`, reboot and verify that it
survives. Likewise, verify SSH host-key continuity and Docker's data-root.

## 5. Updating the installed system

The copy under `/etc/nixos/framework-dev-nixos-live` remains persistent:

```sh
sudo git -C /etc/nixos/framework-dev-nixos-live pull --ff-only
sudo nixos-rebuild switch \
  --flake /etc/nixos/framework-dev-nixos-live#installed
```

Future updates use normal NixOS generations and rollbacks. Disk formatting is
**not** repeated by `nixos-rebuild`.

## Scope and limitations

- This is a headless single-SSD UEFI baseline with ext4 and an ESP, not an
  unattended disk installer. Target choice is always manual.
- There is no storage encryption or swap configured by default.
- The generic NVMe initrd configuration should be checked against
  `nixos-generate-config` on the target hardware before relying on unattended
  boots.
- Keep login tokens and service credentials out of the flake and repository.
- No hardware-specific identifiers, account tokens, or secrets are committed.
- The live image and the persistent installation deliberately share the
  toolchain while using different storage and boot configuration.
