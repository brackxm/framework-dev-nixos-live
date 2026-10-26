# Framework Dev NixOS Live

Declarative, headless NixOS live development environment that boots from removable media and runs with ephemeral storage. The machine hostname is `dev`, accessible over SSH as `ssh dev`.

> **Status:** configuration draft. The ISO has not been built or hardware-tested. Builds are manual-only.

## ISO profiles

- **bootstrap:** minimal image for verifying boot, wired networking, SSH and mDNS.
- **dev:** development tooling, including Node.js, pnpm, Python, Git, GitHub CLI, Codex, Wrangler, Temporal CLI, PostgreSQL client, Docker, Compose, and `elan` for Lean. Proprietary CLIs are optional runtime installs.

The profiles target x86-64 NixOS with a recent kernel, `copytoram`, and a volatile root filesystem. Containers and other application services run on demand. The ISO does not package proprietary Claude Code or 1Password binaries.

## Lean projects

The `dev` image includes `elan`, Lean's version manager (including `lean` and `lake` proxy executables). Lean toolchains and Mathlib are downloaded on demand according to each project's `lean-toolchain` and Lake configuration.

```sh
cd /workspace/your-lean-project
lake --version         # resolves the project's Lean toolchain
lake exe cache get     # fetches precompiled Mathlib cache, where supported
lake build
```

Toolchains, Mathlib sources, and build output live in ephemeral runtime storage and are not baked into the ISO.

## Optional proprietary tools

After boot, the development image provides an explicit helper to download proprietary CLI tools into the current user's ephemeral Nix profile:

```sh
install-runtime-tools claude op
```

Either tool can be installed separately. Neither is downloaded during ISO builds or installed automatically at boot. The helper temporarily permits unfree packages for the requested commands, requires network access, and does not handle authentication. Installation may need repeating after reboot. Runtime installation is not yet hardware-tested.

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

The ISO build and release upload have not been validated yet. Nixpkgs is pinned to a specific 26.05 revision. The developer toolchain pins Node.js **24.22.1** and pnpm **11.25.0** using upstream integrity hashes, but its Nix build has not yet been tested.

The separate **Check Nix flake (no build)** workflow is manual-only. It runs `nix flake check --no-build --show-trace --all-systems` using the committed `flake.lock`. Both profiles and both ISO derivations passed evaluation on the pinned Nixpkgs revision; the images have **not** been built or boot tested. GitHub Actions manual workflows require a same-named workflow on the default branch to appear in the UI.

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

## Runtime model

- The base OS and declared tools are included in the image.
- `/workspace` is capped at 12 GiB of RAM-backed storage for repositories and builds.
- Docker runs on a 16 GiB ext4 loop image backed by a separate 20 GiB capped tmpfs at `/var/lib/dev-ram`, because Docker overlay2 should not use tmpfs directly.
- Limits are not physical RAM reservations. Other memory-backed stores and running services share the system's RAM.
- Containerized applications can be started on demand; a separate native PostgreSQL server is not needed for container-managed databases.
- Changes to the ephemeral filesystem, database contents, sessions, and authentication state do **not** survive reboot.
- Secrets are supplied at runtime, never embedded in the ISO.
- The NixOS modules can be adapted for an installed system with persistent storage.

## Validation checklist

- Firmware and Secure Boot compatibility for unattended USB startup
- Correct package attributes, executable availability, and tool version pins
- ISO size within target removable-media capacity
- SSH, mDNS, and SFTP from a remote client
- RAM-backed ext4 Docker mount, backing image capacity, and Docker storage-driver compatibility
- Containerized development services, resource usage, and SSH port forwarding

## License

Original materials: copyright © 2026 brackxm. All rights reserved. See [LICENSE](LICENSE). Third-party software is licensed separately.
