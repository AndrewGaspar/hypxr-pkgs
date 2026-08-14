#!/bin/bash

set -euo pipefail

for value in HYPXR_PRIMARY_FINGERPRINT HYPXR_SIGNING_SUBKEY_FINGERPRINT; do
  if [[ -z ${!value:-} ]]; then
    echo "ERROR: $value environment variable not set" >&2
    exit 1
  fi
done

key_identity=$(gpg --batch --with-colons --with-subkey-fingerprint \
  --list-secret-keys 2>/dev/null |
  awk -F: -v expected_primary="$HYPXR_PRIMARY_FINGERPRINT" \
    -v expected_signing="$HYPXR_SIGNING_SUBKEY_FINGERPRINT" '
      $1 == "sec" { record = "sec"; primary_marker = $15; next }
      $1 == "ssb" { record = "ssb"; secret_marker = $15; next }
      $1 == "fpr" && record == "sec" {
        primary_records++
        primary = $10
        record = ""
        next
      }
      $1 == "fpr" && record == "ssb" {
        if (secret_marker == "+") {
          secret_subkeys++
          if ($10 == expected_signing) signing = $10
        }
        record = ""
      }
      END {
        if (primary_records == 1 && primary == expected_primary && primary_marker == "#" &&
            signing == expected_signing && secret_subkeys == 1) {
          print primary ":" signing
        }
      }
    ')

if [[ $key_identity != "$HYPXR_PRIMARY_FINGERPRINT:$HYPXR_SIGNING_SUBKEY_FINGERPRINT" ]]; then
  echo "ERROR: Signing export must contain one operational secret subkey and a primary-key stub" >&2
  echo "ERROR: Full primary-key and recovery-subkey exports are rejected" >&2
  exit 1
fi

echo "  ✓ Secret primary key is an offline stub: $HYPXR_PRIMARY_FINGERPRINT"
echo "  ✓ Sole secret signing subkey: $HYPXR_SIGNING_SUBKEY_FINGERPRINT"
