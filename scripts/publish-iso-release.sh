#!/usr/bin/env bash
set -euo pipefail

# Create a draft GitHub Release, not an Actions artifact, for the ISO.
# The run must be manually dispatched. Nothing is published automatically.
profile="${1:?Usage: publish-iso-release.sh bootstrap|dev}"
case "$profile" in
  bootstrap|dev) ;;
  *) echo "Invalid ISO profile: $profile" >&2; exit 2 ;;
esac

: "${GH_TOKEN:?GH_TOKEN is required}"
: "${GH_REPO:?GH_REPO is required}"
: "${GITHUB_SHA:?GITHUB_SHA is required}"
: "${GITHUB_RUN_ID:?GITHUB_RUN_ID is required}"
: "${GITHUB_RUN_ATTEMPT:?GITHUB_RUN_ATTEMPT is required}"

shopt -s nullglob
isos=(result/iso/*.iso)
if (( ${#isos[@]} != 1 )); then
  echo "Expected exactly one ISO at result/iso/*.iso; found ${#isos[@]}" >&2
  exit 1
fi

iso="${isos[0]}"
name="${iso##*/}"
bytes=$(stat -L -c '%s' "$iso")
printf 'ISO: %s (%s bytes)\n' "$name" "$bytes"

# Reserve a margin for USB labels and differences in nominal disk capacity.
if (( bytes > 3750000000 )); then
  echo "ISO exceeds the configured 3.75 GB limit for removable media" >&2
  exit 1
fi

workdir=$(mktemp -d "${RUNNER_TEMP:-/tmp}/iso-release-XXXXXX")
trap 'rm -rf -- "$workdir"' EXIT

hash=$(sha256sum "$iso" | cut -d ' ' -f 1)
printf '%s  %s\n' "$hash" "$name" > "$workdir/SHA256SUMS"

# GitHub Release assets must be < 2 GiB. Use a conservative 1.9 GB
# chunk size to stay below that limit; this needs additional runner disk
# space only when the ISO is above the chunk threshold.
chunk_bytes=1900000000
chunked=false
if (( bytes > chunk_bytes )); then
  split --bytes="$chunk_bytes" --numeric-suffixes=0 --suffix-length=3 \
    "$iso" "$workdir/${name}.part-"
  assets=("$workdir/${name}.part-"*)
  chunked=true
else
  assets=("$iso")
fi

tag="iso-${profile}-${GITHUB_RUN_ID}-a${GITHUB_RUN_ATTEMPT}"
if [[ "$chunked" == true ]]; then
  restoration="cat '${name}'.part-* > '${name}'"
else
  restoration="# Downloaded release contains ${name} directly."
fi

cat > "$workdir/RELEASE_NOTES.md" <<EOF
Development ISO build (draft, not published).

- Profile: ${profile}
- Source commit: ${GITHUB_SHA}
- Image: ${name}
- Bytes: ${bytes}
- SHA-256: ${hash}
- Parts: ${#assets[@]}

Download assets with an authenticated GitHub CLI:

\`\`\`sh
gh release download ${tag} --repo ${GH_REPO}
${restoration}
shasum -a 256 -c SHA256SUMS
\`\`\`

Once the checksum passes, flash the ISO with a suitable disk-image writer.
The image has not been verified on hardware by this workflow.
EOF

# Unique per run/attempt, and targets the exact feature-branch commit.
# Contents write is granted only to the build job's GitHub token.
url=$(gh release create "$tag" "${assets[@]}" "$workdir/SHA256SUMS" \
  --repo "$GH_REPO" \
  --draft \
  --target "$GITHUB_SHA" \
  --title "NixOS ${profile} ISO · run ${GITHUB_RUN_ID}" \
  --notes-file "$workdir/RELEASE_NOTES.md")

echo "Draft release created: $url"
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "## NixOS ${profile} ISO"
    echo
    echo "Draft release: $url"
    echo
    echo "ISO size: ${bytes} bytes"
    echo
    echo "SHA-256: \`${hash}\`"
    echo
    echo "Asset parts: ${#assets[@]}"
  } >> "$GITHUB_STEP_SUMMARY"
fi
