#!/usr/bin/env bash
set -euo pipefail

# Publish a flashable disk image to a DRAFT GitHub Release only.
# No image is sent to GitHub Actions artifact storage.
: "${GH_TOKEN:?GH_TOKEN is required}"
: "${GH_REPO:?GH_REPO is required}"
: "${GITHUB_SHA:?GITHUB_SHA is required}"
: "${GITHUB_RUN_ID:?GITHUB_RUN_ID is required}"
: "${GITHUB_RUN_ATTEMPT:?GITHUB_RUN_ATTEMPT is required}"

shopt -s nullglob
images=(result/*.img)
if (( ${#images[@]} != 1 )); then
  printf 'Expected one .img under result/; found %s\n' "${#images[@]}" >&2
  exit 1
fi
image="${images[0]}"
basename="${image##*/}"
size=$(stat -L -c '%s' "$image")
echo "Raw SSD image: $basename ($size bytes)"

workdir=$(mktemp -d "${RUNNER_TEMP:-/tmp}/ssd-release-XXXXXX")
trap 'rm -rf -- "$workdir"' EXIT

sha=$(sha256sum "$image" | cut -d ' ' -f 1)
printf '%s  %s\n' "$sha" "$basename" > "$workdir/SHA256SUMS"

# Stream compression directly into chunks to avoid storing duplicate full
# compressed images on the limited GitHub-hosted runner disk.
gzip -1 -n -c "$image" | split -b 1900000000 -d -a 3 - "$workdir/${basename}.gz.part-"
assets=("$workdir/${basename}.gz.part-"*)
if (( ${#assets[@]} < 1 )); then
  echo "Compression did not produce release parts" >&2
  exit 1
fi

tag="ssd-${GITHUB_RUN_ID}-a${GITHUB_RUN_ATTEMPT}"
cat > "$workdir/RELEASE_NOTES.md" <<EOF
Bootable NixOS x86-64 SSD image (draft).

- Source commit: ${GITHUB_SHA}
- Raw filename: ${basename}
- Raw image size: ${size} bytes
- Raw SHA-256: ${sha}
- Compressed parts: ${#assets[@]}

This is a GPT/UEFI disk image with a 1 GiB EFI partition and an ext4 root.
The root filesystem grows on first boot after flashing to a larger SSD.
The image is unencrypted and has not been verified on physical hardware.

Download and reconstruct on macOS:

\`\`\`sh
gh release download ${tag} -R ${GH_REPO}
cat '${basename}'.gz.part-* | gzip -dc > '${basename}'
shasum -a 256 -c SHA256SUMS
\`\`\`

**Flash only to the externally connected SSD you intend to completely erase.**
Read docs/flash-ssd-from-mac.md in the repository before writing.
EOF
url=$(gh release create "$tag" "${assets[@]}" "$workdir/SHA256SUMS" \
  --repo "$GH_REPO" --draft --target "$GITHUB_SHA" \
  --title "NixOS SSD image · run ${GITHUB_RUN_ID}" \
  --notes-file "$workdir/RELEASE_NOTES.md")
echo "Draft SSD image release: $url"
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "## SSD image created"
    echo
    echo "Draft release: $url"
    echo
    echo "Raw image size: $size bytes"
    echo
    echo "SHA-256: \`$sha\`"
    echo
    echo "Compressed parts: ${#assets[@]}"
  } >> "$GITHUB_STEP_SUMMARY"
fi
