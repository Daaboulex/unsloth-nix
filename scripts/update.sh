#!/usr/bin/env bash
# Custom updater for unsloth-nix — re-pins TWO independent git sources
# (unslothai/unsloth + unslothai/unsloth-zoo) tracking `main`.
#
# The canonical (single-source) updater can't drive two srcs, each needing its
# own rev + freshly prefetched hash, so this repo declares upstream.type=custom
# (which exempts it from std-conformance byte-syncing) and ships this script.
#
# Contract (Nix Packaging Standard):
#   exit 0  no update needed, or update applied + verified
#   exit 1  real failure (read/write/prefetch/eval/build)  -> workflow files an issue
#   exit 2  network/API error                              -> retried next run, no issue
# Outputs (to $GITHUB_OUTPUT if set): updated old_version new_version
#   package_name upstream_url error_type
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_JSON="$REPO_ROOT/version.json"
README="$REPO_ROOT/README.md"
PACKAGE_NAME="unsloth-nix"
UPSTREAM_URL="https://github.com/unslothai/unsloth"

out() { [ -n "${GITHUB_OUTPUT:-}" ] && printf '%s=%s\n' "$1" "$2" >>"$GITHUB_OUTPUT"; }
die() {
  echo "::error::$2" >&2
  out error_type "$1"
  out package_name "$PACKAGE_NAME"
  out updated false
  exit "${3:-1}"
}

command -v jq >/dev/null || die config-error "jq is required" 1
[ -f "$VERSION_JSON" ] || die config-error "version.json not found" 1

# repo name on GitHub keyed by the version.json attribute name
declare -A GH_REPO=( [unsloth]=unsloth [unsloth-zoo]=unsloth-zoo )

old_unsloth=$(jq -r '.unsloth.rev' "$VERSION_JSON")
old_zoo=$(jq -r '."unsloth-zoo".rev' "$VERSION_JSON")

# --- detect upstream movement (network -> exit 2 on failure) ---
declare -A NEW_REV
for key in unsloth unsloth-zoo; do
  rev=$(git ls-remote "https://github.com/unslothai/${GH_REPO[$key]}.git" refs/heads/main 2>/dev/null | cut -f1)
  [ -n "$rev" ] || die network-error "git ls-remote failed for ${GH_REPO[$key]}" 2
  NEW_REV[$key]=$rev
done

if [ "${NEW_REV[unsloth]}" = "$old_unsloth" ] && [ "${NEW_REV[unsloth-zoo]}" = "$old_zoo" ]; then
  echo "Already up to date (unsloth ${old_unsloth:0:7}, unsloth-zoo ${old_zoo:0:7})."
  out updated false
  out package_name "$PACKAGE_NAME"
  exit 0
fi

DATE=$(date -u +%F)
tmp=$(mktemp)
cp "$VERSION_JSON" "$tmp"

for key in unsloth unsloth-zoo; do
  rev=${NEW_REV[$key]}
  cur=$(jq -r --arg k "$key" '.[$k].rev' "$VERSION_JSON")
  [ "$rev" = "$cur" ] && continue

  # nix-prefetch-github yields the exact NAR hash fetchFromGitHub expects.
  hash=$(nix run nixpkgs#nix-prefetch-github -- unslothai "${GH_REPO[$key]}" --rev "$rev" --json 2>/dev/null | jq -r '.hash')
  [ -n "$hash" ] && [ "$hash" != "null" ] || { rm -f "$tmp"; die network-error "prefetch failed for ${GH_REPO[$key]}" 2; }

  # rev-only scheme: bump rev + hash + a date-stamped version, keep the base.
  base=$(jq -r --arg k "$key" '.[$k].version | sub("-unstable-.*$"; "")' "$VERSION_JSON")
  jq --arg k "$key" --arg rev "$rev" --arg hash "$hash" --arg ver "${base}-unstable-${DATE}" \
    '.[$k].rev=$rev | .[$k].hash=$hash | .[$k].version=$ver' "$tmp" >"$tmp.next" && mv "$tmp.next" "$tmp"
done

jq --arg d "$DATE" '.date=$d' "$tmp" >"$tmp.next" && mv "$tmp.next" "$tmp"
mv "$tmp" "$VERSION_JSON"

# new rev shorthands for the summary (README embeds no rev; version.json is
# the single source of truth, so nothing else to rewrite).
new_u=$(jq -r '.unsloth.rev' "$VERSION_JSON")
new_z=$(jq -r '."unsloth-zoo".rev' "$VERSION_JSON")

# --- verify: eval forces the cuda/rocm gates; build the cache-backed cpu env ---
if ! nix flake check --no-build "$REPO_ROOT"; then
  die eval-error "nix flake check failed after bump"
fi
if ! nix build --no-link "$REPO_ROOT#cpu"; then
  die build-error "nix build .#cpu failed after bump"
fi

old_version="${old_unsloth:0:7}+${old_zoo:0:7}"
new_version="${new_u:0:7}+${new_z:0:7}"
echo "Updated: $old_version -> $new_version"
out updated true
out old_version "$old_version"
out new_version "$new_version"
out package_name "$PACKAGE_NAME"
out upstream_url "$UPSTREAM_URL"
exit 0
