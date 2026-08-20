#!/bin/bash

set -euo pipefail

ROOT=$(realpath "${BASH_SOURCE[0]%/*}/..")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/packages" "$work/pkgroot"

for package in "$ROOT"/pkgbuilds/*; do
  [[ -f $package/PKGBUILD ]] || continue
  name=${package##*/}
  mkdir -p "$work/pkgroot/$name"
  printf '%s\n' \
    "pkgname = $name" \
    "pkgbase = $name" \
    'pkgver = 1.0-1' \
    'arch = any' \
    >"$work/pkgroot/$name/.PKGINFO"
  bsdtar -caf "$work/packages/$name-1.0-1-any.pkg.tar.zst" \
    -C "$work/pkgroot/$name" .PKGINFO
done

"$ROOT/bin/create-release-manifest" \
  --directory "$work/packages" \
  --output "$work/release-manifest.json" \
  --repository AndrewGaspar/hypxr-pkgs \
  --source-commit 0123456789abcdef0123456789abcdef01234567 \
  --workflow-run-id 123 \
  --workflow-run-attempt 1 \
  --mirror edge \
  --arch x86_64

jq -e '
  .schema == 1 and
  .repository == "AndrewGaspar/hypxr-pkgs" and
  .source_commit == "0123456789abcdef0123456789abcdef01234567" and
  (.packages | length) == 12 and
  all(.packages[]; (.sha256 | test("^[0-9a-f]{64}$")) and .bytes > 0)
' "$work/release-manifest.json" >/dev/null

"$ROOT/bin/verify-release-manifest" \
  --manifest "$work/release-manifest.json" \
  --directory "$work/packages" \
  --repository AndrewGaspar/hypxr-pkgs \
  --source-commit 0123456789abcdef0123456789abcdef01234567 \
  --workflow-run-id 123 \
  --workflow-run-attempt 1 \
  --mirror edge \
  --arch x86_64

if "$ROOT/bin/verify-release-manifest" \
  --manifest "$work/release-manifest.json" \
  --directory "$work/packages" \
  --repository AndrewGaspar/hypxr-pkgs \
  --source-commit fedcba9876543210fedcba9876543210fedcba98 \
  --workflow-run-id 123 \
  --workflow-run-attempt 1 \
  --mirror edge \
  --arch x86_64 >/dev/null 2>&1; then
  echo "FAIL: release manifest accepted the wrong source commit" >&2
  exit 1
fi

printf 'changed\n' >>"$work/packages/hypxrland-1.0-1-any.pkg.tar.zst"
if "$ROOT/bin/verify-release-manifest" \
  --manifest "$work/release-manifest.json" \
  --directory "$work/packages" \
  --repository AndrewGaspar/hypxr-pkgs \
  --source-commit 0123456789abcdef0123456789abcdef01234567 \
  --workflow-run-id 123 \
  --workflow-run-attempt 1 \
  --mirror edge \
  --arch x86_64 >/dev/null 2>&1; then
  echo "FAIL: release manifest accepted changed package content" >&2
  exit 1
fi
bsdtar -caf "$work/packages/hypxrland-1.0-1-any.pkg.tar.zst" \
  -C "$work/pkgroot/hypxrland" .PKGINFO

rm "$work/packages/hypxrhud-1.0-1-any.pkg.tar.zst"
if "$ROOT/bin/create-release-manifest" \
  --directory "$work/packages" \
  --output "$work/incomplete.json" \
  --repository AndrewGaspar/hypxr-pkgs \
  --source-commit 0123456789abcdef0123456789abcdef01234567 \
  --workflow-run-id 123 \
  --workflow-run-attempt 1 \
  --mirror edge \
  --arch x86_64 >/dev/null 2>&1; then
  echo "FAIL: release manifest accepted an incomplete package wave" >&2
  exit 1
fi

echo "Release manifest checks passed"
