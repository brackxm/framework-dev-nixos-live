# Framework Dev NixOS Live

Declarative, headless NixOS development environment with live USB images and a persistent installed-system profile. The machine hostname is `dev`, accessible over SSH as `ssh dev`.

> **Status:** Live ISOs and the raw SSD image have been built but not verified on target hardware. The installed-system profile passes `nix flake check --no-build` and still requires disk installation and boot testing. ISO builds are manual-only.

## ISO profiles

- **bootstrap:** minimal image for verifying boot, wired networking, SSH and mDNS.
- **dev (live ISO):** development tooling, including Node.js, pnpm, Python, Git, GitHub CLI, Codex, Wrangler, Temporal CLI, PostgreSQL client, Docker, Compose, and `elan` for Lean. Proprietary CLIs are optional runtime installs.

Flake configuration names are `nixosConfigurations.devLive` (live dev image) and `nixosConfigurations.installed` (persistent SSD system). `packages.x86_64-linux.devIso` and the manual workflow's `dev` profile are unchanged for compatibility. The shared `nix/dev.nix` module contains development tools for both configurations.

The live profiles target x86-64 NixOS with a recent kernel, `copytoram`, and a volatile root filesystem. An additional **installed** profile uses a persistent ext4 root, UEFI systemd-boot, and the same development tools without RAM-backed Docker mounts. See [SSD installation](docs/install-to-ssd.md). Proprietary Claude Code and 1Password binaries are not included in the ISO.

## Lean projects

The `dev` image includes `elan`, Lean's version manager (including `lean` and `lake` proxy executables). Lean toolchains and Mathlib are downloaded on demand according to each project's `lean-toolchain` and Lake configuration.

```sh
cd /workspace/your-lean-project
lake --version         # resolves the project's Lean toolchain
lake exe cache get     # fetches precompiled Mathlib cache, where supported
lake build
```

Toolchains and Mathlib are fetched on demand rather than baked into the live ISO; their runtime state is ephemeral on live media and persistent on an installed system.

## Persistent installation

Only the SSD-installed configuration imports the **pinned Framework Desktop AMD AI Max 300 Series** hardware module from `nixos-hardware`; it supplies AMD CPU/GPU defaults, TRIM, and `framework-tool`. It also enables `fwupd` for **user-initiated** firmware updates. Live USB profiles remain hardware-generic. The hardware pin is recorded in `flake.lock`.

The flake exposes `nixosConfigurations.installed` for a normal SSD-backed workstation. It retains SSH, the `dev` hostname, the same development packages and a persistent `/workspace`; it does **not** format disks or import the live ISO's RAM-only mounts. It expects an ext4 filesystem labeled `nixos` and an EFI System Partition labeled `ESP`, matching the raw EFI image.

**Do not run any disk preparation commands until the target device has been independently verified.** Follow [the installation guide](docs/install-to-ssd.md). A standard NixOS installer session can install the profile through `nixos-install --flake ...#installed`.

## Installed-system maintenance and diagnostics

The installed configuration adds `nix/maintenance.nix` and
`nix/hardware/framework-desktop.nix` without changing the live ISO's
RAM-backed storage or the upstream Framework hardware module.

- **Nix GC:** Every Sunday at 03:00, prune NixOS generations older than
  30 days and collect unreferenced store paths. Recent generations remain
  available for rollback; project files and Docker volumes are unaffected.
- **Nix store optimization:** Sundays at 05:00, deduplicate identical
  store files. It is independent of project/Docker storage.
- **Hardware tools (installed only):** `sensors` (lm_sensors), `nvtop`
  (AMD), `nvme` and `smartctl` for temperature, GPU load and SSD health.
  These provide diagnostics, not automatic firmware changes or fan tuning.
- **Zellij (shared dev toolchain):** Run `zellij` over SSH, detach when
  needed and later use `zellij attach`. Sessions survive SSH disconnects
  while the host remains up, not reboots. It becomes available in a newly
  rebuilt live ISO and in the next installed-system build.

The SSD image already published on GitHub **predates these additions**.
A new manually triggered build is needed to include them in a flashed image;
after installation, `nixos-rebuild switch --flake ...#installed` is also an
option.

## Flashable SSD image (Mac + USB enclosure)

The `packages.x86_64-linux.ssdImage` output produces a bootable GPT/UEFI raw
disk image of the **installed** profile, not another live ISO. It includes an
ext4 root and EFI partition, and automatically expands the root partition
and filesystem on the first boot from a larger SSD.

The SSD image was rebuilt successfully with maintenance tools and Zellij
([run #40506161716](https://github.com/brackxm/framework-dev-nixos-live/actions/runs/40506161716)).
The current [draft SSD release](https://github.com/brackxm/framework-dev-nixos-live/releases/tag/untagged-aa941002a2a0a9ada528)
contains compressed image parts and a SHA-256 checksum. The partition table
passed GPT verification, but physical SSD booting remains untested. The
**Build NixOS SSD Image** workflow is manual-only. Download, reconstruct, verify and flash the image with the SSD
connected over USB to a Mac. **Flashing overwrites the selected SSD.**

**Release publishing:** The October 29 Nixpkgs refresh passed evaluation,
SSD image creation and GPT verification, but GitHub refused the draft release
creation (HTTP 403). The October 27 draft above is still the last available
image and does **not** contain the October 29 update. A fresh build needs the
repository Actions secret `SSD_RELEASE_TOKEN`, using a repository-scoped
fine-grained token with **Contents: write** and **Workflows: write** because
the release target differs from the default branch under `.github/workflows/`.
The workflow checks for the secret before building and uses it only for
publishing; see the flash guide for setup.

See [Flash a NixOS SSD image from macOS](docs/flash-ssd-from-mac.md).

## Optional proprietary tools

After boot, both development profiles provide an explicit helper to download proprietary CLI tools into the current user's Nix profile (ephemeral on live media, persistent on an installed system):

```sh
install-runtime-tools claude op
```

Either tool can be installed separately. Neither is downloaded during ISO builds or installed automatically at boot. The helper temporarily permits unfree packages for the requested commands, requires network access, and does not handle authentication. Installation must be repeated after a live-system reboot, but remains available across reboots on a persistent installation. Runtime installation is not yet hardware-tested.

## SSH setup

The ISO reads authorized **public** keys from `ssh/authorized_keys`. Generate a dedicated keypair on the SSH client, if needed:

```sh
ssh-keygen -t ed25519 -a 100 -f ~/.ssh/dev_ed25519 -C dev
cat ~/.ssh/dev_ed25519.pub
```

Add the complete public key to `ssh/authorized_keys`. Never commit a private key, access token or credential.

An example client `~/.ssh/config` entry:

```sshconfig
Host dev
    HostName dev.local
    User nixos
    IdentityFile ~/.ssh/dev_ed25519
    IdentitiesOnly yes
```

Connect with `ssh dev`. If mDNS is unavailable, use the address assigned by DHCP. Wired networking is preferred for initial headless access.

## Building

The `.github/workflows/build-iso.yml` workflow has **only a manual `workflow_dispatch` trigger**; there are no push, pull request, or scheduled builds.

In GitHub Actions, select **Build NixOS Live ISO**, choose `bootstrap` or `dev`, and explicitly run the workflow when ready. The workflow validates SSH key material, checks that the ISO fits the configured removable-media size limit, and uploads it to a **draft GitHub Release** instead of Actions artifact storage. Images above 1.9 GB are split into release assets under 2 GiB each, with a SHA-256 checksum and reassembly instructions. Draft releases remain unpublished until explicitly published.

The existing live ISO build and draft-release upload have succeeded; the installed profile has passed the no-build evaluation and has not been installed or boot tested. Nixpkgs is pinned to a specific 26.05 revision. The developer toolchain pins Node.js **24.22.1** and pnpm **11.25.0** using upstream integrity hashes, but its Nix build has not yet been tested.

The separate **Check Nix flake (no build)** workflow is manual-only. It runs `nix flake check --no-build --show-trace --all-systems` using the committed `flake.lock`. The earlier bootstrap and dev profiles and their ISO derivations passed evaluation on the pinned Nixpkgs revision; the images have **not** been built or boot tested. GitHub Actions manual workflows require a same-named workflow on the default branch to appear in the UI.

## Verification

After boot:

```sh
ssh dev
hostname
free -h
df -h / /nix/store /var/lib/docker
systemctl status sshd
```

The optional `scripts/check-runtime.sh` script reports tool availability and storage/network details when copied to the running system.

## Live runtime model

- The base OS and declared tools are included in the image.
- `/workspace` is capped at 12 GiB of RAM-backed storage for repositories and builds.
- Docker runs on a 16 GiB ext4 loop image backed by a separate 20 GiB capped tmpfs at `/var/lib/dev-ram`, because Docker overlay2 should not use tmpfs directly.
- Limits are not physical RAM reservations. Other memory-backed stores and running services share the system's RAM.
- Containerized applications can be started on demand; a separate native PostgreSQL server is not needed for container-managed databases.
- Changes to the ephemeral filesystem, database contents, sessions, and authentication state do **not** survive reboot.
- Secrets are supplied at runtime, never embedded in the ISO.
- The NixOS modules can be adapted for an installed system with persistent storage.

## Validation checklist

- The new installed-system configuration must pass `nix flake check --no-build` before installation
- Installed system must boot from the intended UEFI disk and retain `/workspace`, SSH host keys, users and Docker data

- Firmware and Secure Boot compatibility for unattended USB startup
- Correct package attributes, executable availability, and tool version pins
- ISO size within target removable-media capacity
- SSH, mDNS, and SFTP from a remote client
- RAM-backed ext4 Docker mount, backing image capacity, and Docker storage-driver compatibility
- Containerized development services, resource usage, and SSH port forwarding

## License

Original materials: copyright © 2026 brackxm. All rights reserved. See [LICENSE](LICENSE). Third-party software is licensed separately.
