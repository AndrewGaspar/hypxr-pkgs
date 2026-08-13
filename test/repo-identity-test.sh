#!/bin/bash

set -euo pipefail

ROOT=$(realpath "${BASH_SOURCE[0]%/*}/..")
cd "$ROOT"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[[ $(git remote get-url upstream 2>/dev/null || true) == "https://github.com/omacom-io/omarchy-pkgs.git" ]] ||
  fail "upstream remote does not track omacom-io/omarchy-pkgs"

if rg -n 'omarchy-build|omarchy\.db|omarchy-pkg-builder|OMARCHY_REPO_HOST|OMARCHY_STATE_DIR|/root/omarchy-pkgs|/root/\.omarchy/build-credentials' \
  bin build helpers systemd .gitignore; then
  fail "found stale Omarchy repository identity"
fi

rg -q 'REPO_DIR="\$BUILD_ROOT/repository/\$MIRROR/\$ARCH"' helpers/paths.sh ||
  fail "published repository path is not HypXR-owned"
rg -q 'REPO_NAME="hypxr"' build/update-repo.sh ||
  fail "repository database is not named hypxr"
rg -q '^\[hypxr-build\]$' build/build.sh ||
  fail "current build-wave repository is missing"
rg -q '^\[hypxr\]$' build/build.sh ||
  fail "published HypXR dependency repository is missing"
rg -q '^\[omarchy\]$' build/build.sh ||
  fail "public Omarchy dependency repository is missing"
rg -q 'pkgs\.omarchy\.org/\$MIRROR/' build/build.sh ||
  fail "Omarchy dependency ring does not follow the HypXR ring"

rg -q 'sign-database' bin/release || fail "release does not sign databases"
rg -q 'hypxr\.db\.tar\.zst\.sig' build/sign-database.sh ||
  fail "database signature is not produced"
rg -q 'PackageRequired DatabaseRequired TrustedOnly' README.md ||
  fail "client signature policy is not documented"
rg -q 'HYPXR_PRIMARY_FINGERPRINT' build/sign.sh ||
  fail "signer does not pin the offline primary fingerprint"
rg -q 'HYPXR_SIGNING_SUBKEY_FINGERPRINT' build/sign.sh ||
  fail "signer does not select an explicit operational signing subkey"
rg -q 'HYPXR_PUBLIC_KEY' build/verify-database.sh ||
  fail "database verification does not use public-only key material"
rg -q 'max-age=31536000, immutable' bin/sync-repo ||
  fail "immutable package cache policy is missing"
rg -q 'no-store, max-age=0, must-revalidate' bin/sync-repo ||
  fail "mutable repository metadata cache policy is missing"

if rg -n 'HYPXR_SIGNING_FINGERPRINT' bin build README.md; then
  fail "found obsolete ambiguous signing fingerprint variable"
fi

for generator in bin/create-keyring-package bin/render-bootstrap; do
  [[ -x $generator ]] || fail "$generator is not executable"
  bash -n "$generator"
done

echo "Repository identity checks passed"
