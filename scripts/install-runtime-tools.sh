#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: install-runtime-tools claude [op]
       install-runtime-tools op [claude]

Install proprietary command-line tools into the current user's ephemeral
Nix profile on request, not during the ISO build.

  claude    Claude Code CLI
  op        1Password CLI

Authenticate separately after installation.
USAGE
}

if [[ $# -eq 0 || "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

# Scope acceptance of unfree packages to these explicit commands.
# Use the same fixed Nixpkgs revision as the ISO; package versions are pinned by it.
base="github:NixOS/nixpkgs/1f607aa79b6356ed45d3cd3c8079c196e79efa2c"

for tool in "$@"; do
  case "$tool" in
    claude) attr="claude-code" ;;
    op) attr="_1password-cli" ;;
    *)
      printf 'Unknown tool: %s\n' "$tool" >&2
      usage >&2
      exit 2
      ;;
  esac

  printf 'Installing %s from %s (network required)...\n' "$tool" "$base"
  NIXPKGS_ALLOW_UNFREE=1 nix profile install --impure "${base}#${attr}"
done

printf '\nInstalled. If binaries are not found, open a new login shell or use ~/.nix-profile/bin.\n'
