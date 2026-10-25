#!/usr/bin/env bash
set -euo pipefail
if ! grep -Eq '^ssh-(ed25519|rsa|ecdsa-sha2-nistp256) [A-Za-z0-9+/=]+' ssh/authorized_keys; then
  echo 'Missing public SSH key; add the SSH client's public key to ssh/authorized_keys' >&2
  exit 1
fi
if grep -Eq 'PRIVATE KEY|REPLACE_WITH' ssh/authorized_keys; then
  echo 'Refusing placeholder or private key in ssh/authorized_keys' >&2
  exit 1
fi
