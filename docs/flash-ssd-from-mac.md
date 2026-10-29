# Flash a prebuilt NixOS SSD from macOS

This is an alternative to installing NixOS from the live USB. The GitHub
workflow produces a **raw disk image**, complete with a GPT partition table,
1 GiB EFI System Partition and ext4 root containing the installed development
environment. Download the image to a Mac and flash it to an SSD connected via
a USB-to-NVMe enclosure, then put the SSD into the target computer.

**Warning: flashing a disk image irreversibly overwrites the target SSD.**
Back up all data on that drive and independently verify the target before
writing. Do not flash your Mac's internal disk, or the only recovery USB.

## 1. Build the image

From GitHub Actions, manually launch **Build NixOS SSD Image** on branch
`feat/nixos-installed`. The build checks the GPT layout and uploads compressed
image parts to a **draft** GitHub Release; the release must be downloaded with
GitHub CLI authentication.

**One-time release credential setup:** GitHub requires a token with both
**Contents: read and write** and **Workflows: read and write** when a release
targets a commit whose workflow files differ from the default branch. The
built-in `GITHUB_TOKEN` cannot obtain the Workflows permission. Create a
fine-grained personal access token scoped **only to this repository** with those
two repository permissions, then store it under GitHub **Settings → Secrets
and variables → Actions → New repository secret** as `SSD_RELEASE_TOKEN`.
Prefer a short-lived token and rotate or revoke it when not needed. Never
commit a token or put one in the disk image. The workflow checks that the
secret exists before starting the expensive image build, and only passes
it to the GitHub Release publication step. Without it, the build fails early
and the existing release remains intact.

Image contents are not encrypted. The image contains the intended SSH **public**
key for user `nixos`, not a password or private key. Before exposing it to an
untrusted network, review passwordless sudo and SSH access.

The latest raw SSD image ([run #40506161716](https://github.com/brackxm/framework-dev-nixos-live/actions/runs/40506161716))
is approximately **15.38 GB uncompressed** and **3.78 GB compressed**. Reserve at least **20 GB of free Mac storage** for the
downloaded parts and reconstructed image, and use an SSD larger than the raw image.

## 2. Download and reconstruct on the Mac

Install and authenticate the GitHub CLI if needed. Use the tag from the
successful run's draft release, in place of `RELEASE_TAG` (currently `ssd-40506161716-a1`):

```sh
mkdir -p ~/Downloads/nixos-ssd
cd ~/Downloads/nixos-ssd

gh release download RELEASE_TAG \
  -R brackxm/framework-dev-nixos-live

# Stream-decompress: no need to join the .gz parts into a second large file.
cat framework-dev-ssd.img.gz.part-* | gzip -dc > framework-dev-ssd.img
shasum -a 256 -c SHA256SUMS
```

**Proceed only if the checksum reports OK.** The filename and digest are
provided in the release notes.

## 3. Flash the USB-connected SSD

Connect the *SSD* using a USB-to-NVMe enclosure. In macOS, inspect disks:

```sh
diskutil list external physical
```

Confirm the device's capacity, manufacturer/model and external connection.
Prefer a graphical raw-image writer such as balenaEtcher: select the verified
`framework-dev-ssd.img`, **carefully select the external SSD**, flash, then
eject it.

An alternative for experienced users only is macOS `dd`, after replacing
`diskN` with the **verified external SSD identifier** (never copy the
placeholder as-is):

```sh
diskutil unmountDisk /dev/diskN
sudo dd if=framework-dev-ssd.img of=/dev/rdiskN bs=4m
sync
diskutil eject /dev/diskN
```

The image's GPT/ESP/ext4 partitions are already prepared. macOS may report
that it cannot read the Linux partitions; do **not** initialize or erase them.

## 4. Boot from the SSD

Power down the target computer, install the SSD internally and choose it as
the UEFI boot device. Prefer **wired Ethernet** for the first headless boot;
Wi-Fi settings are not embedded in the image.

The hostname is `dev`, user `nixos`, SSH accepts the checked-in authorized
public key, and password login is disabled:

```sh
ssh dev
lsblk -f
findmnt /
df -h /
```

The raw image's root filesystem has the label `nixos`, and EFI has label
`ESP`. NixOS is configured to grow the last GPT partition and resize the
ext4 filesystem on first boot to consume the available disk space.

If SSH warns about a changed host key, independently verify the new host's
fingerprint before accepting it. New SSH host keys are expected for a fresh
installation.

## 5. Verify persistence and preserve the configuration

After confirming network access, clone the repo to the installed SSD so you
can upgrade the OS with the `installed` configuration:

```sh
sudo mkdir -p /etc/nixos
sudo git clone --branch feat/nixos-installed --single-branch \
  https://github.com/brackxm/framework-dev-nixos-live.git \
  /etc/nixos/framework-dev-nixos-live

sudo nixos-rebuild switch \
  --flake /etc/nixos/framework-dev-nixos-live#installed
```

Verify that `/workspace`, Docker data and SSH host keys survive a reboot.
The SSD image is an **unencrypted baseline**, not a secure/TPM-enrolled or
production-hardened deployment.

The earlier **manual** SSD installation method using the Live USB is still
documented in [install-to-ssd.md](install-to-ssd.md).
