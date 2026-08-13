#!/bin/bash

set -e

ARCH=${ARCH:-x86_64}
MIRROR=${MIRROR:-edge}
REPO_DIR="/repository/$MIRROR/$ARCH"

if [[ -z ${GPG_PRIVATE_KEY:-} || -z ${HYPXR_SIGNING_FINGERPRINT:-} ]]; then
  echo "ERROR: GPG_PRIVATE_KEY and HYPXR_SIGNING_FINGERPRINT must be set"
  exit 1
fi

echo "$GPG_PRIVATE_KEY" | gpg --batch --import 2>/dev/null

for database in hypxr.db.tar.zst hypxr.files.tar.zst; do
  if ! gpg --batch --status-fd 1 \
    --verify "$REPO_DIR/$database.sig" "$REPO_DIR/$database" 2>/dev/null |
    grep -q "^\[GNUPG:\] VALIDSIG $HYPXR_SIGNING_FINGERPRINT "; then
    echo "ERROR: Invalid or unexpected signature for $database"
    exit 1
  fi
done

echo "==> HypXR repository database signatures verified"
