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

if [[ -z ${HYPXR_PRIMARY_FINGERPRINT:-} ]]; then
  echo "ERROR: HYPXR_PRIMARY_FINGERPRINT environment variable not set"
  exit 1
fi

if [[ -z ${HYPXR_SIGNING_SUBKEY_FINGERPRINT:-} ]]; then
  echo "ERROR: HYPXR_SIGNING_SUBKEY_FINGERPRINT environment variable not set"
  exit 1
fi

echo "$GPG_PRIVATE_KEY" | gpg --batch --import 2>/dev/null
key_identity=$(gpg --batch --with-colons --with-subkey-fingerprint \
  --list-secret-keys "$HYPXR_PRIMARY_FINGERPRINT" 2>/dev/null |
  awk -F: -v expected_primary="$HYPXR_PRIMARY_FINGERPRINT" \
    -v expected_signing="$HYPXR_SIGNING_SUBKEY_FINGERPRINT" '
      $1 == "sec" { record = "sec"; next }
      $1 == "ssb" { record = "ssb"; next }
      $1 == "fpr" && record == "sec" && primary == "" { primary = $10; record = ""; next }
      $1 == "fpr" && record == "ssb" { if ($10 == expected_signing) signing = $10; record = "" }
      END { if (primary == expected_primary && signing == expected_signing) print primary ":" signing }
    ')

if [[ $key_identity != "$HYPXR_PRIMARY_FINGERPRINT:$HYPXR_SIGNING_SUBKEY_FINGERPRINT" ]]; then
  echo "ERROR: Imported signing subkey is not attached to the expected primary key"
  exit 1
fi

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
