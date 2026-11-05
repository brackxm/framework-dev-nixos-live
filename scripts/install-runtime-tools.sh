#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: install-runtime-tools claude [op]
       install-runtime-tools op [claude]

Install or update proprietary CLI tools in the current user's Nix profile.
This state persists only on installed systems.

  claude    Current upstream Claude Code release, using the pinned Nix wrapper
  op        1Password CLI from the workstation's pinned Nixpkgs revision

Authenticate separately. Restart running Claude sessions/services after an update.
USAGE
}

if [[ $# -eq 0 || "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

# Validate the complete request before downloading or changing the profile.
for tool in "$@"; do
  case "$tool" in
    claude|op) ;;
    *) printf 'Unknown tool: %s\n' "$tool" >&2; usage >&2; exit 2 ;;
  esac
done

base="github:NixOS/nixpkgs/08d3a97586f6b6343b3b5e799980773629432610"

install_claude() (
  releases="https://downloads.claude.ai/claude-code-releases"
  version=$(curl --fail --silent --show-error --location "$releases/latest")
  if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf 'Invalid Claude release version: %s\n' "$version" >&2
    exit 1
  fi

  manifest=$(mktemp)
  trap 'rm -f -- "$manifest"' EXIT
  curl --fail --silent --show-error --location \
    "$releases/$version/manifest.json" --output "$manifest"
  jq --exit-status --arg version "$version" '
    .version == $version and
    (.platforms | type == "object" and length > 0) and
    all(.platforms[]; .checksum | test("^[0-9a-fA-F]{64}$"))
  ' "$manifest" > /dev/null

  printf 'Preparing Claude Code %s with the pinned Nix wrapper...\n' "$version"
  # Release metadata is read only at runtime. fetchurl in the existing package
  # verifies the selected platform binary against its manifest checksum.
  package=$(FRAMEWORK_CLAUDE_MANIFEST="$manifest" NIXPKGS_ALLOW_UNFREE=1 \
    nix build --impure --no-link --print-out-paths --expr "
      let
        source = builtins.getFlake \"$base\";
        pkgs = import source { system = builtins.currentSystem; };
      in pkgs.claude-code.override {
        manifest = builtins.fromJSON (builtins.readFile
          (builtins.getEnv \"FRAMEWORK_CLAUDE_MANIFEST\"));
      }
    ")
  "$package/bin/claude" --version

  previous=$(nix profile list --json | jq --raw-output '
    (.elements["claude-code"].storePaths // []) |
    if length <= 1 then .[0] // ""
    else error("claude-code has multiple store paths; inspect the profile first") end
  ')
  if [[ "$previous" == "$package" ]]; then
    printf 'Claude Code %s is already installed.\n' "$version"
    exit 0
  fi

  # Finish the build before replacing anything. Keep other tools untouched and
  # restore the previous Claude package if adding its replacement fails.
  if [[ -n "$previous" ]]; then
    nix profile remove claude-code
  fi
  if ! nix profile add "$package"; then
    if [[ -n "$previous" ]]; then
      printf 'Restoring the previous Claude package...\n' >&2
      nix profile add "$previous"
    fi
    exit 1
  fi
)

for tool in "$@"; do
  case "$tool" in
    claude) install_claude ;;
    op)
      printf 'Installing op from %s (network required)...\n' "$base"
      NIXPKGS_ALLOW_UNFREE=1 nix profile install --impure "${base}#_1password-cli"
      ;;
  esac
done

printf '\nDone. Open a new login shell if needed, or use ~/.nix-profile/bin.\n'
