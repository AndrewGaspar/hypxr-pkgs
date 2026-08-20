#!/bin/bash

set -euo pipefail

ROOT=$(realpath "${BASH_SOURCE[0]%/*}/..")
cd "$ROOT"

packages=(
  hypxrhud
  hypxr-keyring
  hypxrland
  hypxrland-legacy-config
  hypxrland-omarchy
  hypxrland-stack
  hypxrpaper
  hypxrva
  hypxrvoice-model-base-en
  hypxrvoice
  monado-xreal
  wivrn-hypxr
)

for package in "${packages[@]}"; do
  package_dir="pkgbuilds/$package"
  [[ -f $package_dir/PKGBUILD ]]
  [[ -f $package_dir/.omarchy/package.json ]]
  jq -e '.source == "local" and length == 1' \
    "$package_dir/.omarchy/package.json" >/dev/null
  bash -n "$package_dir/PKGBUILD"

  actual_name=$(cd "$package_dir" && bash -c 'source PKGBUILD; printf "%s" "$pkgname"')
  [[ $actual_name == "$package" ]]

  if rg -n '/usr/(local|lib64|libexec)(/|$)' "$package_dir"; then
    echo "FAIL: $package contains a non-Arch installation path" >&2
    exit 1
  fi
done

for package in \
  hypxr-keyring \
  hypxrland-legacy-config \
  hypxrland-omarchy \
  hypxrland-stack \
  hypxrvoice-model-base-en; do
  [[ $(cd "pkgbuilds/$package" && bash -c 'source PKGBUILD; printf "%s" "${arch[*]}"') == "any" ]]
done

for package in \
  hypxrhud \
  hypxrland \
  hypxrpaper \
  hypxrva \
  hypxrvoice \
  monado-xreal \
  wivrn-hypxr; do
  [[ $(cd "pkgbuilds/$package" && bash -c 'source PKGBUILD; printf "%s" "${arch[*]}"') == "x86_64" ]]
done

rg -q -- '-DCMAKE_INSTALL_LIBDIR=lib' pkgbuilds/hypxrva/PKGBUILD
rg -q '/usr/share/hypxrvoice/models/ggml-base\.en\.bin' \
  pkgbuilds/hypxrvoice-model-base-en/PKGBUILD

rg -q "'omarchy-settings>=4\.0\.0rc3'" \
  pkgbuilds/hypxrland-legacy-config/PKGBUILD
rg -q "'omarchy-settings<4\.1'" pkgbuilds/hypxrland-legacy-config/PKGBUILD
rg -Fq "s|~/.local/share/omarchy|/usr/share/omarchy|g" \
  pkgbuilds/hypxrland-legacy-config/PKGBUILD
rg -q "'omarchy>=4\.0\.0rc3'" pkgbuilds/hypxrland-omarchy/PKGBUILD
rg -q "'omarchy<4\.1'" pkgbuilds/hypxrland-omarchy/PKGBUILD
rg -q "'hypxrland-legacy-config'" pkgbuilds/hypxrland-omarchy/PKGBUILD
rg -q "'hypxrland-stack'" pkgbuilds/hypxrland-omarchy/PKGBUILD
rg -q "'monado-xreal: private" pkgbuilds/hypxrland-stack/PKGBUILD

rg -q '^Name=Omarchy XR$' pkgbuilds/hypxrland-omarchy/omarchy-xr.desktop
rg -q '^Exec=/usr/bin/omarchy-xr-session$' \
  pkgbuilds/hypxrland-omarchy/omarchy-xr.desktop
rg -q '^TryExec=/usr/bin/omarchy-xr-session$' \
  pkgbuilds/hypxrland-omarchy/omarchy-xr.desktop
rg -q '^  /usr/bin/omarchy-setup-hypxrland$' \
  pkgbuilds/hypxrland-omarchy/omarchy-xr-session
rg -q '^exec /usr/bin/hypxrland-session "\$@"$' \
  pkgbuilds/hypxrland-omarchy/omarchy-xr-session

setup_tmp=$(mktemp -d)
trap 'rm -rf "$setup_tmp"' EXIT

if gpg --batch --list-packets pkgbuilds/hypxr-keyring/hypxr.gpg 2>/dev/null |
  grep -Eq '^:(secret key|secret sub key) packet:'; then
  echo "FAIL: hypxr-keyring contains secret key material" >&2
  exit 1
fi
mapfile -t trust_fingerprints < <(
  gpg --batch --show-keys --with-colons pkgbuilds/hypxr-keyring/hypxr.gpg |
    awk -F: '$1 == "fpr" { print $10 }'
)
(( ${#trust_fingerprints[@]} == 2 ))
rg -Fq "EXPECTED_PRIMARY_FINGERPRINT='${trust_fingerprints[0]}'" install-hypxr.sh
awk '/^-----BEGIN PGP PUBLIC KEY BLOCK-----$/,/^-----END PGP PUBLIC KEY BLOCK-----$/' \
  install-hypxr.sh >"$setup_tmp/installer-key.asc"
gpg --batch --dearmor --output "$setup_tmp/installer-key.gpg" \
  "$setup_tmp/installer-key.asc"
cmp pkgbuilds/hypxr-keyring/hypxr.gpg "$setup_tmp/installer-key.gpg"

mkdir -p "$setup_tmp/config/hypr"
printf '%s\n' 'packaged template' >"$setup_tmp/template"
HOME="$setup_tmp/home" \
XDG_CONFIG_HOME="$setup_tmp/config" \
HYPXRLAND_OMARCHY_TEMPLATE="$setup_tmp/template" \
  bash pkgbuilds/hypxrland-omarchy/omarchy-setup-hypxrland >/dev/null
printf '%s\n' 'user customization' >>"$setup_tmp/config/hypr/hyprland-xr.conf"
HOME="$setup_tmp/home" \
XDG_CONFIG_HOME="$setup_tmp/config" \
HYPXRLAND_OMARCHY_TEMPLATE="$setup_tmp/template" \
  bash pkgbuilds/hypxrland-omarchy/omarchy-setup-hypxrland >/dev/null
[[ $(<"$setup_tmp/config/hypr/hyprland-xr.conf") == $'packaged template\nuser customization' ]]

rg -q '^source = /usr/share/omarchy/default/hypr/autostart\.conf$' \
  pkgbuilds/hypxrland-omarchy/hyprland-xr.conf
rg -q '^openxr \{$' pkgbuilds/hypxrland-omarchy/hyprland-xr.conf
rg -q '^exec-once = systemctl --user start wivrn\.service$' \
  pkgbuilds/hypxrland-omarchy/hyprland-xr.conf

echo "Package-wave checks passed"
