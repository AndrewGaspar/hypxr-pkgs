#!/bin/bash

set -euo pipefail

EXPECTED_PRIMARY_FINGERPRINT='74C1F43250AF5125B17FF459644F84BDBE2CAFCE'
REPO_BASE='https://hypxr.omedora.org'
CHANNEL='edge'

if (( EUID != 0 )); then
  echo 'ERROR: Run this installer as root (for example, curl ... | sudo bash)' >&2
  exit 1
fi

if grep -Eq '^\[hypxr\][[:space:]]*$' /etc/pacman.conf; then
  echo 'ERROR: /etc/pacman.conf already contains a [hypxr] repository' >&2
  exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export GNUPGHOME="$work/gnupg"
mkdir -m 0700 "$GNUPGHOME"

cat >"$work/hypxr.gpg.asc" <<'HYPXR_PUBLIC_KEY'
-----BEGIN PGP PUBLIC KEY BLOCK-----

mDMEaocmzBYJKwYBBAHaRw8BAQdAfRDHNoFdtT9TDKXuLEYDUcK3aAK7H4ThTbs/
jNkEsge0L0h5cFhSIFBhY2thZ2UgUmVwb3NpdG9yeSA8cGFja2FnZXNAb21lZG9y
YS5vcmc+iJYEExYKAD4WIQR0wfQyUK9RJbF/9FlkT4S9viyvzgUCaocmzAIbAQUJ
AHanAAULCQgHAgYVCgkICwIEFgIDAQIeAQIXgAAKCRBkT4S9viyvzjxlAP0cZWyW
Ciot5RoFIhi7+jOwrPmNcjRdhBkjX/sm28HaNQEAhpUEmd/MgFCEcOfDbxudCRiQ
VgE8ukGV0iMSiTMEXg64MwRqhyb9FgkrBgEEAdpHDwEBB0A1MnF+35IscU00XlTS
4ARObV8S/vHqVD/4HaK9Ojp+iYj1BBgWCgAmFiEEdMH0MlCvUSWxf/RZZE+Evb4s
r84FAmqHJv0CGwIFCQB2pwAAgQkQZE+Evb4sr852IAQZFgoAHRYhBK5NSZHEXf3H
kjUFodVkqXQAkfOKBQJqhyb9AAoJENVkqXQAkfOKdSABAKkdvyVGdnNFD+RgB57H
mBeBOo5rBGOrr7fSYebfcl9lAP9JJKSSymurFnG/3rZy5fZOvDDMgFEfOy63zTNm
lvIjA7dmAQDDlrockMcp24SXCRNapcXX7OFVLAzmaPwA6ds6BDxsIgD/bzTYFfym
6m8ck3kk3w+ZUenjXkp/CckKgqv4Qqo7swk=
=KXxA
-----END PGP PUBLIC KEY BLOCK-----
HYPXR_PUBLIC_KEY

mapfile -t fingerprints < <(gpg --batch --show-keys --with-colons "$work/hypxr.gpg.asc" |
  awk -F: '$1 == "pub" { want = 1; next } want && $1 == "fpr" { print toupper($10); want = 0 }')

if (( ${#fingerprints[@]} != 1 )) || [[ ${fingerprints[0]} != "$EXPECTED_PRIMARY_FINGERPRINT" ]]; then
  echo 'ERROR: Embedded HypXR key does not match the pinned primary fingerprint' >&2
  exit 1
fi

unset GNUPGHOME
pacman-key --init
pacman-key --add "$work/hypxr.gpg.asc"
pacman-key --lsign-key "$EXPECTED_PRIMARY_FINGERPRINT"

cp /etc/pacman.conf "$work/pacman.conf"
cat >>"$work/pacman.conf" <<REPOSITORY

[hypxr]
SigLevel = PackageRequired DatabaseRequired TrustedOnly
Server = $REPO_BASE/$CHANNEL/\$arch
REPOSITORY

pacman --config "$work/pacman.conf" -Syu --noconfirm --needed hypxr-keyring
install -m 0644 "$work/pacman.conf" /etc/pacman.conf

echo 'HypXR repository enabled. Install the XR session with:'
echo '  sudo pacman -Syu hypxrland-omarchy'
