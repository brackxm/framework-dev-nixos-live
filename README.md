# Framework Dev NixOS Live

Declarative, headless NixOS live development environment that boots from removable media and runs with ephemeral storage. The machine hostname is `dev`, accessible over SSH as `ssh dev`.

> **Status:** configuration draft. The ISO has not been built or hardware-tested. Builds are manual-only.

## ISO profiles

- **bootstrap:** minimal image for verifying boot, wired networking, SSH and mDNS.
- **dev:** development tooling, including Node.js, pnpm, Python, Git, GitHub CLI, Codex, Wrangler, Temporal CLI, PostgreSQL client, Docker and Compose. Proprietary CLIs are optional runtime installs.

The profiles target x86-64 NixOS with a recent kernel, `copytoram`, and a volatile root filesystem. Containers and other application services run on demand. The ISO does not package proprietary Claude Code or 1Password binaries.

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

In GitHub Actions, select **Build NixOS Live ISO**, choose `bootstrap` or `dev`, and explicitly run the workflow when ready. The workflow validates SSH key material, checks image size against the configured limit, and uploads a short-lived artifact.

The build has not been validated yet. A committed `flake.lock`, exact dependency pins, package evaluation, and ISO-size verification are required before relying on the resulting image.

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
- Repositories, package caches, container images, service data, and builds use writable runtime storage.
- Containerized applications can be started on demand; a separate native PostgreSQL server is not needed for container-managed databases.
- Changes to the ephemeral filesystem, database contents, sessions, and authentication state do **not** survive reboot.
- Secrets are supplied at runtime, never embedded in the ISO.
- The NixOS modules can be adapted for an installed system with persistent storage.

## Validation checklist

- Firmware and Secure Boot compatibility for unattended USB startup
- Correct package attributes, executable availability, and tool version pins
- ISO size within target removable-media capacity
- SSH, mDNS, and SFTP from a remote client
- RAM-backed writable storage and Docker storage-driver compatibility
- Containerized development services, resource usage, and SSH port forwarding

## License

Original materials: copyright © 2026 brackxm. All rights reserved. See [LICENSE](LICENSE). Third-party software is licensed separately.
