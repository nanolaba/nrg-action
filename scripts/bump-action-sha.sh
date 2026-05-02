#!/usr/bin/env bash
# Bump the canonical nanolaba/nrg-action commit SHA across README.md
# and examples/*.yml.
#
# Why this script exists:
#   The README and example workflows pin nanolaba/nrg-action to an exact
#   commit SHA (with a "# v1" marker for humans). When a new release is
#   cut, the floating `v1` tag moves to a new commit — and every pinned
#   SHA in our docs becomes stale until manually bumped.
#
#   Run this script as part of the release process. It also bumps the
#   "Current canonical SHA" callout in README.md, picking the most
#   specific same-commit tag (e.g. v1.3) for the human-readable label.
#
# Usage:
#   ./scripts/bump-action-sha.sh           # bump to current `v1` tip
#   ./scripts/bump-action-sha.sh v1.3      # bump to a specific tag
#
# After running, review with `git diff` and commit.
set -euo pipefail

cd "$(dirname "$0")/.."

TAG="${1:-v1}"

git fetch --tags --force origin >/dev/null 2>&1 || true

if ! NEW_SHA="$(git rev-parse --verify "${TAG}^{commit}" 2>/dev/null)"; then
  echo "error: tag '${TAG}' not found locally. Try: git fetch --tags origin" >&2
  exit 1
fi

# Pick the most specific same-commit tag for the human label, falling
# back to the input tag. Sort by version so v1.10 > v1.2.
LABEL="$(git tag --points-at "$NEW_SHA" | grep -E '^v[0-9]+(\.[0-9]+)+$' | sort -V | tail -n1 || true)"
LABEL="${LABEL:-$TAG}"

echo "Bumping nanolaba/nrg-action SHA → ${NEW_SHA}  # ${LABEL}"

shopt -s nullglob
TARGETS=(README.md examples/*.yml)

for f in "${TARGETS[@]}"; do
  sed -i.bak -E "s|nanolaba/nrg-action@[a-f0-9]{40}|nanolaba/nrg-action@${NEW_SHA}|g" "$f"
  rm -f "${f}.bak"
done

# Update the "Current canonical SHA" callout in README.md.
sed -i.bak -E \
  "s|\\*\\*Current canonical SHA:\\*\\* \`[a-f0-9]{40}\` resolves to \`v[0-9.]+\`|**Current canonical SHA:** \`${NEW_SHA}\` resolves to \`${LABEL}\`|" \
  README.md
rm -f README.md.bak

echo "Done. Review with: git diff"
