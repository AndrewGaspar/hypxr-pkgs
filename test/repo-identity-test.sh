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

echo "Repository identity checks passed"
