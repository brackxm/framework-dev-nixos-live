#!/usr/bin/env bash
set -u
printf '\n=== Host / memory / storage ===\n'
hostname
uname -a
free -h
df -h / /nix/store "$HOME"
printf '\n=== SSH / Docker ===\n'
systemctl --no-pager status sshd | head -15 || true
if command -v docker >/dev/null; then
  docker info --format 'Driver={{.Driver}} Root={{.DockerRootDir}}' || true
fi
printf '\n=== Development tools ===\n'
for tool in git gh codex claude wrangler op temporal node pnpm python3 psql; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf '%-12s %s\n' "$tool" "$(command -v "$tool")"
  else
    printf '%-12s MISSING\n' "$tool"
  fi
done
printf '\nTarget versions: Node 24.22.1; pnpm 11.25.0\n'
command -v node >/dev/null && node --version || true
command -v pnpm >/dev/null && pnpm --version || true
