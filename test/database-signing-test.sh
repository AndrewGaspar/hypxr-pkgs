#!/bin/bash

set -euo pipefail

ROOT=$(realpath "${BASH_SOURCE[0]%/*}/..")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

export GNUPGHOME="$work/gnupg"
mkdir -m 0700 "$GNUPGHOME"

if ! gpg --batch --pinentry-mode loopback --passphrase test-passphrase --quick-generate-key \
  'HypXR Repository Test <test@hypxr.invalid>' rsa2048 cert 1d >/dev/null 2>&1; then
  echo "SKIP: local sandbox does not permit gpg-agent key generation"
  exit 0
fi

primary_fingerprint=$(gpg --batch --with-colons --list-secret-keys |
  awk -F: '$1 == "fpr" { print $10; exit }')
gpg --batch --pinentry-mode loopback --passphrase test-passphrase \
  --quick-add-key "$primary_fingerprint" rsa2048 sign 1d >/dev/null 2>&1
signing_subkey_fingerprint=$(gpg --batch --with-colons --with-subkey-fingerprint \
  --list-secret-keys "$primary_fingerprint" |
  awk -F: '$1 == "ssb" { subkey = 1; next } subkey && $1 == "fpr" { print $10; exit }')
gpg --batch --pinentry-mode loopback --passphrase test-passphrase \
  --quick-add-key "$primary_fingerprint" rsa2048 sign 1d >/dev/null 2>&1
private_key=$(gpg --batch --pinentry-mode loopback --passphrase test-passphrase \
  --armor --export-secret-subkeys "$signing_subkey_fingerprint!")
multiple_subkeys_key=$(gpg --batch --pinentry-mode loopback --passphrase test-passphrase \
  --armor --export-secret-subkeys "$primary_fingerprint")
full_private_key=$(gpg --batch --pinentry-mode loopback --passphrase test-passphrase \
  --armor --export-secret-keys "$primary_fingerprint")
public_key=$(gpg --batch --armor --export "$primary_fingerprint")

mkdir -p "$work/repository"
printf 'database\n' >"$work/repository/hypxr.db.tar.zst"
printf 'files database\n' >"$work/repository/hypxr.files.tar.zst"

rm -rf "$GNUPGHOME"
mkdir -m 0700 "$GNUPGHOME"

GPG_PRIVATE_KEY="$private_key" \
GPG_PASSPHRASE=test-passphrase \
HYPXR_PRIMARY_FINGERPRINT="$primary_fingerprint" \
HYPXR_SIGNING_SUBKEY_FINGERPRINT="$signing_subkey_fingerprint" \
REPO_DIR="$work/repository" \
  "$ROOT/build/sign-database.sh"

rm -rf "$GNUPGHOME"
mkdir -m 0700 "$GNUPGHOME"
if GPG_PRIVATE_KEY="$full_private_key" \
  GPG_PASSPHRASE=test-passphrase \
  HYPXR_PRIMARY_FINGERPRINT="$primary_fingerprint" \
  HYPXR_SIGNING_SUBKEY_FINGERPRINT="$signing_subkey_fingerprint" \
  REPO_DIR="$work/repository" \
  "$ROOT/build/sign-database.sh" >/dev/null 2>&1; then
  echo "FAIL: signer accepted a usable primary secret key" >&2
  exit 1
fi

rm -rf "$GNUPGHOME"
mkdir -m 0700 "$GNUPGHOME"
if GPG_PRIVATE_KEY="$multiple_subkeys_key" \
  GPG_PASSPHRASE=test-passphrase \
  HYPXR_PRIMARY_FINGERPRINT="$primary_fingerprint" \
  HYPXR_SIGNING_SUBKEY_FINGERPRINT="$signing_subkey_fingerprint" \
  REPO_DIR="$work/repository" \
  "$ROOT/build/sign-database.sh" >/dev/null 2>&1; then
  echo "FAIL: signer accepted an extra recovery secret subkey" >&2
  exit 1
fi

rm -rf "$GNUPGHOME"
mkdir -m 0700 "$GNUPGHOME"

HYPXR_PUBLIC_KEY="$public_key" \
HYPXR_PRIMARY_FINGERPRINT="$primary_fingerprint" \
HYPXR_SIGNING_SUBKEY_FINGERPRINT="$signing_subkey_fingerprint" \
REPO_DIR="$work/repository" \
  "$ROOT/build/verify-database.sh"

for database in hypxr.db.tar.zst hypxr.files.tar.zst; do
  gpg --batch --verify \
    "$work/repository/$database.sig" "$work/repository/$database" >/dev/null 2>&1
done

wrong_signing_fingerprint=$(printf '0%.0s' {1..40})
if HYPXR_PUBLIC_KEY="$public_key" \
  HYPXR_PRIMARY_FINGERPRINT="$primary_fingerprint" \
  HYPXR_SIGNING_SUBKEY_FINGERPRINT="$wrong_signing_fingerprint" \
  REPO_DIR="$work/repository" \
  "$ROOT/build/verify-database.sh" >/dev/null 2>&1; then
  echo "FAIL: database verification accepted the wrong signing subkey" >&2
  exit 1
fi

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
