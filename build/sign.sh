#!/bin/bash
# Sign packages in build-output (runs inside Docker)

set -e

ARCH=${ARCH:-x86_64}
MIRROR=${MIRROR:-edge}
BUILD_OUTPUT_DIR="/build-output/$MIRROR/$ARCH"

echo "==> Package Signing"
echo "==> Target architecture: $ARCH"
echo "==> Mirror: $MIRROR"
echo "==> Build output: $BUILD_OUTPUT_DIR"

# Check if GPG key and passphrase are provided
if [[ -z "$GPG_PRIVATE_KEY" ]]; then
  echo "ERROR: GPG_PRIVATE_KEY environment variable not set"
  exit 1
fi

if [[ -z "$GPG_PASSPHRASE" ]]; then
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

# Import GPG key
echo "==> Importing GPG signing key..."
echo "$GPG_PRIVATE_KEY" | gpg --batch --import 2>/dev/null || {
  echo "ERROR: Failed to import signing key"
  exit 1
}

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

echo "  ✓ GPG trust root loaded: $HYPXR_PRIMARY_FINGERPRINT"
echo "  ✓ GPG signing subkey loaded: $HYPXR_SIGNING_SUBKEY_FINGERPRINT"

# Check if build output exists and has packages
if [[ ! -d "$BUILD_OUTPUT_DIR" ]]; then
  echo "ERROR: Build output directory not found: $BUILD_OUTPUT_DIR"
  exit 1
fi

cd "$BUILD_OUTPUT_DIR"

# Find all unsigned package files
PACKAGE_FILES=$(ls -1 *.pkg.tar.zst 2>/dev/null || true)

if [[ -z "$PACKAGE_FILES" ]]; then
  echo "==> No packages found to sign"
  exit 0
fi

PACKAGE_COUNT=$(echo "$PACKAGE_FILES" | wc -l)
echo "==> Found $PACKAGE_COUNT package(s) to sign"
echo ""

# Sign all packages
SIGNED_COUNT=0
FAILED_COUNT=0

for pkg_file in $PACKAGE_FILES; do
  echo -n "  -> $pkg_file ... "
  
  # Remove existing signature if present
  rm -f "$pkg_file.sig"
  
  # Sign the package
  if gpg --batch --yes --pinentry-mode loopback --passphrase "$GPG_PASSPHRASE" \
    --detach-sign --use-agent --no-armor \
    --local-user "$HYPXR_SIGNING_SUBKEY_FINGERPRINT!" "$pkg_file" 2>/dev/null; then
    echo "✓"
    SIGNED_COUNT=$((SIGNED_COUNT + 1))
  else
    echo "✗"
    FAILED_COUNT=$((FAILED_COUNT + 1))
  fi
done

echo ""

# Summary
if [[ $FAILED_COUNT -eq 0 ]]; then
  echo "==> Successfully signed all $SIGNED_COUNT package(s)"
  exit 0
else
  echo "==> Signed $SIGNED_COUNT package(s), failed $FAILED_COUNT"
  exit 1
fi
