#!/bin/bash

set -e

ARCH=${ARCH:-x86_64}
MIRROR=${MIRROR:-edge}
REPO_DIR=${REPO_DIR:-/repository/$MIRROR/$ARCH}

if [[ -z ${GPG_PRIVATE_KEY:-} ]]; then
  echo "ERROR: GPG_PRIVATE_KEY environment variable not set"
  exit 1
fi

if [[ -z ${GPG_PASSPHRASE:-} ]]; then
  echo "ERROR: GPG_PASSPHRASE environment variable not set"
  exit 1
fi

if [[ -z ${HYPXR_SIGNING_FINGERPRINT:-} ]]; then
  echo "ERROR: HYPXR_SIGNING_FINGERPRINT environment variable not set"
  exit 1
fi

echo "$GPG_PRIVATE_KEY" | gpg --batch --import 2>/dev/null
key_fingerprint=$(gpg --batch --with-colons --with-subkey-fingerprint \
  --list-secret-keys "$HYPXR_SIGNING_FINGERPRINT" 2>/dev/null |
  awk -F: -v expected="$HYPXR_SIGNING_FINGERPRINT" '$1 == "fpr" && $10 == expected { print $10; exit }')

if [[ $key_fingerprint != "$HYPXR_SIGNING_FINGERPRINT" ]]; then
  echo "ERROR: Imported key does not match HYPXR_SIGNING_FINGERPRINT"
  exit 1
fi

cd "$REPO_DIR"

for database in hypxr.db.tar.zst hypxr.files.tar.zst; do
  if [[ ! -f $database ]]; then
    echo "ERROR: Repository database not found: $REPO_DIR/$database"
    exit 1
  fi

  gpg --batch --yes --pinentry-mode loopback \
    --passphrase "$GPG_PASSPHRASE" \
    --detach-sign --local-user "$key_fingerprint!" "$database"
  gpg --batch --verify "$database.sig" "$database"
done

ln -sfn hypxr.db.tar.zst.sig hypxr.db.sig
ln -sfn hypxr.files.tar.zst.sig hypxr.files.sig

echo "==> Signed HypXR repository databases with $key_fingerprint"
