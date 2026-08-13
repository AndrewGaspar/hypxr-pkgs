#!/bin/bash

set -e

ARCH=${ARCH:-x86_64}
MIRROR=${MIRROR:-edge}
REPO_DIR=${REPO_DIR:-/repository/$MIRROR/$ARCH}

if [[ -z ${HYPXR_PUBLIC_KEY:-} || -z ${HYPXR_PRIMARY_FINGERPRINT:-} || \
  -z ${HYPXR_SIGNING_SUBKEY_FINGERPRINT:-} ]]; then
  echo "ERROR: HYPXR_PUBLIC_KEY, HYPXR_PRIMARY_FINGERPRINT, and"
  echo "       HYPXR_SIGNING_SUBKEY_FINGERPRINT must be set"
  exit 1
fi

echo "$HYPXR_PUBLIC_KEY" | gpg --batch --import 2>/dev/null

for database in hypxr.db.tar.zst hypxr.files.tar.zst; do
  if ! gpg --batch --status-fd 1 \
    --verify "$REPO_DIR/$database.sig" "$REPO_DIR/$database" 2>/dev/null |
    awk -v signing="$HYPXR_SIGNING_SUBKEY_FINGERPRINT" \
      -v primary="$HYPXR_PRIMARY_FINGERPRINT" '
        $1 == "[GNUPG:]" && $2 == "VALIDSIG" && $3 == signing && $NF == primary { valid = 1 }
        END { exit valid ? 0 : 1 }
      '; then
    echo "ERROR: Invalid or unexpected signature for $database"
    exit 1
  fi
done

echo "==> HypXR repository database signatures verified"
