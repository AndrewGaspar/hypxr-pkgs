#!/bin/bash

set -e

ARCH=${ARCH:-x86_64}
MIRROR=${MIRROR:-edge}
REPO_DIR=${REPO_DIR:-/repository/$MIRROR/$ARCH}
SCRIPT_DIR=$(realpath "${BASH_SOURCE[0]%/*}")

if [[ -z ${GPG_PRIVATE_KEY:-} ]]; then
  echo "ERROR: GPG_PRIVATE_KEY environment variable not set"
  exit 1
fi

if [[ -z ${GPG_PASSPHRASE:-} ]]; then
  echo "ERROR: GPG_PASSPHRASE environment variable not set"
  exit 1
fi

if [[ -z ${HYPXR_PRIMARY_FINGERPRINT:-} ]]; then
  echo "ERROR: HYPXR_PRIMARY_FINGERPRINT environment variable not set"
  exit 1
fi

if [[ -z ${HYPXR_SIGNING_SUBKEY_FINGERPRINT:-} ]]; then
  echo "ERROR: HYPXR_SIGNING_SUBKEY_FINGERPRINT environment variable not set"
  exit 1
fi

echo "$GPG_PRIVATE_KEY" | gpg --batch --import 2>/dev/null
HYPXR_PRIMARY_FINGERPRINT="$HYPXR_PRIMARY_FINGERPRINT" \
HYPXR_SIGNING_SUBKEY_FINGERPRINT="$HYPXR_SIGNING_SUBKEY_FINGERPRINT" \
  "$SCRIPT_DIR/verify-signing-key.sh"

cd "$REPO_DIR"

for database in hypxr.db.tar.zst hypxr.files.tar.zst; do
  if [[ ! -f $database ]]; then
    echo "ERROR: Repository database not found: $REPO_DIR/$database"
    exit 1
  fi

  printf '%s\n' "$GPG_PASSPHRASE" | gpg --batch --yes \
    --pinentry-mode loopback --passphrase-fd 0 --detach-sign \
    --local-user "$HYPXR_SIGNING_SUBKEY_FINGERPRINT!" "$database"
  gpg --batch --verify "$database.sig" "$database"
done

ln -sfn hypxr.db.tar.zst.sig hypxr.db.sig
ln -sfn hypxr.files.tar.zst.sig hypxr.files.sig

echo "==> Signed HypXR repository databases with $HYPXR_SIGNING_SUBKEY_FINGERPRINT"
