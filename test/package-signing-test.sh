#!/bin/bash

set -euo pipefail

ROOT=$(realpath "${BASH_SOURCE[0]%/*}/..")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

export GNUPGHOME="$work/gnupg"
mkdir -m 0700 "$GNUPGHOME"

if ! gpg --batch --pinentry-mode loopback --passphrase test-passphrase --quick-generate-key \
  'HypXR Package Test <test@hypxr.invalid>' rsa2048 cert 1d >/dev/null 2>&1; then
  echo "SKIP: local sandbox does not permit gpg-agent key generation"
  exit 0
fi

export HYPXR_PRIMARY_FINGERPRINT
HYPXR_PRIMARY_FINGERPRINT=$(gpg --batch --with-colons --list-secret-keys |
  awk -F: '$1 == "fpr" { print $10; exit }')
gpg --batch --pinentry-mode loopback --passphrase test-passphrase \
  --quick-add-key "$HYPXR_PRIMARY_FINGERPRINT" rsa2048 sign 1d >/dev/null 2>&1
export HYPXR_SIGNING_SUBKEY_FINGERPRINT
HYPXR_SIGNING_SUBKEY_FINGERPRINT=$(gpg --batch --with-colons --with-subkey-fingerprint \
  --list-secret-keys "$HYPXR_PRIMARY_FINGERPRINT" |
  awk -F: '$1 == "ssb" { subkey = 1; next } subkey && $1 == "fpr" { print $10; exit }')
export HYPXR_PUBLIC_KEY
HYPXR_PUBLIC_KEY=$(gpg --batch --armor --export "$HYPXR_PRIMARY_FINGERPRINT")

mkdir "$work/packages"
package="$work/packages/example-1.0-1-any.pkg.tar.zst"
printf 'package\n' >"$package"
printf '%s\n' test-passphrase | gpg --batch --yes --pinentry-mode loopback \
  --passphrase-fd 0 --detach-sign --local-user "$HYPXR_SIGNING_SUBKEY_FINGERPRINT!" \
  "$package"

"$ROOT/bin/verify-packages" --directory "$work/packages"

printf 'changed\n' >>"$package"
if "$ROOT/bin/verify-packages" --directory "$work/packages" >/dev/null 2>&1; then
  echo "FAIL: package verification accepted changed content" >&2
  exit 1
fi

echo "Package signing checks passed"
