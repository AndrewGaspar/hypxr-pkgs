#!/bin/bash

set -euo pipefail

ROOT=$(realpath "${BASH_SOURCE[0]%/*}/..")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

export GNUPGHOME="$work/gnupg"
mkdir -m 0700 "$GNUPGHOME"

if ! gpg --batch --pinentry-mode loopback --passphrase test-passphrase --quick-generate-key \
  'HypXR Repository Test <test@hypxr.invalid>' rsa2048 sign 1d >/dev/null 2>&1; then
  echo "SKIP: local sandbox does not permit gpg-agent key generation"
  exit 0
fi

fingerprint=$(gpg --batch --with-colons --list-secret-keys |
  awk -F: '$1 == "fpr" { print $10; exit }')
private_key=$(gpg --batch --pinentry-mode loopback --passphrase test-passphrase \
  --armor --export-secret-keys "$fingerprint")

mkdir -p "$work/repository"
printf 'database\n' >"$work/repository/hypxr.db.tar.zst"
printf 'files database\n' >"$work/repository/hypxr.files.tar.zst"

rm -rf "$GNUPGHOME"
mkdir -m 0700 "$GNUPGHOME"

GPG_PRIVATE_KEY="$private_key" \
GPG_PASSPHRASE=test-passphrase \
HYPXR_SIGNING_FINGERPRINT="$fingerprint" \
REPO_DIR="$work/repository" \
  "$ROOT/build/sign-database.sh"

for database in hypxr.db.tar.zst hypxr.files.tar.zst; do
  gpg --batch --verify \
    "$work/repository/$database.sig" "$work/repository/$database" >/dev/null 2>&1
done

[[ -L $work/repository/hypxr.db.sig ]]
[[ -L $work/repository/hypxr.files.sig ]]

printf 'changed\n' >>"$work/repository/hypxr.db.tar.zst"
if gpg --batch --verify \
  "$work/repository/hypxr.db.tar.zst.sig" \
  "$work/repository/hypxr.db.tar.zst" >/dev/null 2>&1; then
  echo "FAIL: changed repository database retained a valid signature" >&2
  exit 1
fi

echo "Database signing checks passed"
