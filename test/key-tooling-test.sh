#!/bin/bash

set -euo pipefail

ROOT=$(realpath "${BASH_SOURCE[0]%/*}/..")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

export GNUPGHOME="$work/gnupg"
mkdir -m 0700 "$GNUPGHOME"

if ! gpg --batch --pinentry-mode loopback --passphrase test-passphrase --quick-generate-key \
  'HypXR Key Tooling Test <test@hypxr.invalid>' rsa2048 cert 1d >/dev/null 2>&1; then
  echo "SKIP: local sandbox does not permit gpg-agent key generation"
  exit 0
fi

primary_fingerprint=$(gpg --batch --with-colons --list-secret-keys |
  awk -F: '$1 == "fpr" { print $10; exit }')
gpg --batch --pinentry-mode loopback --passphrase test-passphrase \
  --quick-add-key "$primary_fingerprint" rsa2048 sign 1d >/dev/null 2>&1
gpg --batch --armor --export "$primary_fingerprint" >"$work/public.asc"
gpg --batch --pinentry-mode loopback --passphrase test-passphrase \
  --armor --export-secret-keys "$primary_fingerprint" >"$work/secret.asc"

"$ROOT/bin/create-keyring-package" \
  --public-key "$work/public.asc" \
  --primary-fingerprint "$primary_fingerprint" \
  --output-dir "$work/hypxr-keyring" >/dev/null

[[ $(<"$work/hypxr-keyring/hypxr-trusted") == "$primary_fingerprint:4:" ]]
[[ ! -s $work/hypxr-keyring/hypxr-revoked ]]
gpg --batch --show-keys "$work/hypxr-keyring/hypxr.gpg" >/dev/null 2>&1
bash -n "$work/hypxr-keyring/PKGBUILD"

if "$ROOT/bin/create-keyring-package" \
  --public-key "$work/secret.asc" \
  --primary-fingerprint "$primary_fingerprint" \
  --output-dir "$work/rejected-secret" >/dev/null 2>&1; then
  echo "FAIL: keyring generator accepted secret key material" >&2
  exit 1
fi

"$ROOT/bin/render-bootstrap" \
  --public-key "$work/public.asc" \
  --primary-fingerprint "$primary_fingerprint" \
  --repo-base https://packages.hypxr.dev \
  --channel edge \
  --output "$work/install-hypxr.sh" >/dev/null

bash -n "$work/install-hypxr.sh"
grep -Fq "EXPECTED_PRIMARY_FINGERPRINT='$primary_fingerprint'" "$work/install-hypxr.sh"
grep -Fq 'SigLevel = PackageRequired DatabaseRequired TrustedOnly' "$work/install-hypxr.sh"
grep -Fq 'Server = $REPO_BASE/$CHANNEL/\$arch' "$work/install-hypxr.sh"
grep -Fq 'pacman --config "$work/pacman.conf" -Syu --noconfirm --needed hypxr-keyring' \
  "$work/install-hypxr.sh"

if "$ROOT/bin/render-bootstrap" \
  --public-key "$work/public.asc" \
  --primary-fingerprint "$primary_fingerprint" \
  --repo-base https://packages.example.invalid \
  --output "$work/rejected-placeholder.sh" >/dev/null 2>&1; then
  echo "FAIL: bootstrap generator accepted a placeholder repository host" >&2
  exit 1
fi

echo "Key tooling checks passed"
