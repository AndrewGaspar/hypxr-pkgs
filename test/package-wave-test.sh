#!/bin/bash

set -euo pipefail

ROOT=$(realpath "${BASH_SOURCE[0]%/*}/..")
cd "$ROOT"

packages=(
  hyprpad
  hypxrhud
  hypxrcompose
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
  voxtype-hypxr
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
  hyprpad \
  hypxrhud \
  hypxrcompose \
  hypxrland \
  hypxrpaper \
  hypxrva \
  hypxrvoice \
  monado-xreal \
  voxtype-hypxr \
  wivrn-hypxr; do
  [[ $(cd "pkgbuilds/$package" && bash -c 'source PKGBUILD; printf "%s" "${arch[*]}"') == "x86_64" ]]
done

rg -q -- '-DCMAKE_INSTALL_LIBDIR=lib' pkgbuilds/hypxrva/PKGBUILD
rg -q "'ffmpeg'" pkgbuilds/hypxrcompose/PKGBUILD
rg -q 'upstream hypxr branch' pkgbuilds/wivrn-hypxr/PKGBUILD
rg -q "'libboost_iostreams\.so'" pkgbuilds/wivrn-hypxr/PKGBUILD
rg -q -- '-DWIVRN_BUILD_TEST=ON' pkgbuilds/wivrn-hypxr/PKGBUILD
rg -q 'build/server/take-bundle' pkgbuilds/wivrn-hypxr/PKGBUILD
wivrn_assert_patch=pkgbuilds/wivrn-hypxr/enable-assertions-in-server-tests.patch
[[ -f $wivrn_assert_patch ]]
rg -Fq "'enable-assertions-in-server-tests.patch'" \
  pkgbuilds/wivrn-hypxr/PKGBUILD
expected_wivrn_assert_patch_sum=$(
  cd pkgbuilds/wivrn-hypxr
  bash -c '
    source PKGBUILD
    for ((i = 0; i < ${#source[@]}; i++)); do
      if [[ ${source[i]} == "enable-assertions-in-server-tests.patch" ]]; then
        printf "%s" "${sha256sums[i]}"
      fi
    done
  '
)
[[ $(sha256sum "$wivrn_assert_patch" | cut -d' ' -f1) == "$expected_wivrn_assert_patch_sum" ]]
rg -q 'patch -d "WiVRn-\$_commit" -p1 --forward < enable-assertions-in-server-tests\.patch' \
  pkgbuilds/wivrn-hypxr/PKGBUILD
rg -q 'foreach\(target transfer-pacer take-bundle\)' "$wivrn_assert_patch"
rg -q 'target_compile_options\(\$\{target\} PRIVATE -UNDEBUG\)' \
  "$wivrn_assert_patch"
rg -q '/usr/share/hypxrvoice/models/ggml-base\.en\.bin' \
  pkgbuilds/hypxrvoice-model-base-en/PKGBUILD
rg -q 'resolve/5359861c739e955e79d9a303bcbc70fb988958b1/ggml-base\.en\.bin' \
  pkgbuilds/hypxrvoice-model-base-en/PKGBUILD

# Every publish rebuilds the complete edge wave, and published filenames are
# immutable, so each release must carry a pkgrel no earlier release used.
# The aquamarine 0.15.0 (libaquamarine.so=14) rebuild of hypxrland re-versioned
# the whole wave for that reason.
declare -A expected_pkgrel=(
  [hyprpad]=1
  [hypxr-keyring]=3
  [hypxrcompose]=2
  [hypxrhud]=2
  [hypxrland]=2
  [hypxrland-legacy-config]=2
  [hypxrland-omarchy]=2
  [hypxrland-stack]=2
  [hypxrpaper]=3
  [hypxrva]=3
  [hypxrvoice]=2
  [hypxrvoice-model-base-en]=3
  [monado-xreal]=3
  [voxtype-hypxr]=1
  [wivrn-hypxr]=2
)
for package in "${packages[@]}"; do
  actual_pkgrel=$(cd "pkgbuilds/$package" && bash -c 'source PKGBUILD; printf "%s" "$pkgrel"')
  [[ $actual_pkgrel == "${expected_pkgrel[$package]}" ]]
done

expected_stack_deps=(
  'hypxrland>=0.56.2.r374.g67200a838-2'
  'hypxrcompose>=0.20260820.1.gf75ccd4ec-2'
  'hypxrhud>=0.20260816.1.gf96d0e794-2'
  'hypxrpaper>=0.20260704.1.g5cae848cd-3'
  'hypxrva>=0.20260803.1.gbba2c5f8b-3'
  'hypxrvoice>=0.20260812.1.g7ce7d33b2-2'
  'hypxrvoice-model-base-en>=1.0.0-3'
  'wivrn-hypxr>=26.6.2.20260820.1.g3729c7b31-2'
)
mapfile -t actual_stack_deps < <(
  cd pkgbuilds/hypxrland-stack
  bash -c 'source PKGBUILD; printf "%s\n" "${depends[@]}"'
)
[[ ${actual_stack_deps[*]} == "${expected_stack_deps[*]}" ]]

rg -q '/usr/share/hypxrland/mpv/mpv-hypxr-stereo\.lua' \
  pkgbuilds/hypxrland/PKGBUILD pkgbuilds/hypxrland/README.package.md

# hyprpad ships upstream's host integration under the package-owned paths and
# rewrites the checkout-relative paths its units and scripts carry.
hyprpad_package=pkgbuilds/hyprpad/PKGBUILD
rg -q "'wayland'" "$hyprpad_package"
rg -q -- '--frozen --release' "$hyprpad_package"
rg -q '/usr/lib/sysusers\.d/hyprpad\.conf' "$hyprpad_package"
rg -q '/usr/lib/udev/rules\.d/72-hyprpad-puck\.rules' "$hyprpad_package"
rg -q '/usr/lib/systemd/user/hyprpad\.service' "$hyprpad_package"
rg -q 'hyprpad-broker\.socket packaged/systemd/hyprpad-broker\.service' "$hyprpad_package"
rg -q 'packaged/systemd/user/hyprpad\.service' "$hyprpad_package"
! rg -q 'sed -i' "$hyprpad_package"
rg -Fq 'ExecStart=/usr/bin/hyprpad broker' "$hyprpad_package"
rg -Fq 'Environment=HYPRPAD_OSK_BIN=/usr/bin/hyprpad-osk' "$hyprpad_package"
rg -Fq 'DEFAULT_SRC="/usr/share/hyprpad/shell/$PLUGIN_ID"' "$hyprpad_package"
rg -Fq 'file:///usr/share/doc/hyprpad/12-lizard-free.md' "$hyprpad_package"
rg -Fq 'usermod -aG hyprpad' pkgbuilds/hyprpad/README.package.md
rg -Fq 'hyprpad-broker.socket' pkgbuilds/hyprpad/README.package.md

# voxtype-hypxr replaces Omarchy's voxtype-bin with a source build of the
# Muse fork. It must stay a drop-in for the upstream layout and never inherit
# the build host's CPU features.
voxtype_package=pkgbuilds/voxtype-hypxr/PKGBUILD
rg -q "^conflicts=\('voxtype' 'voxtype-bin' 'voxtype-bin-rc'\)" "$voxtype_package"
rg -q '^provides=\("voxtype=\$_voxtype_compat"\)' "$voxtype_package"
rg -q "^backup=\('etc/voxtype/config\.toml'\)" "$voxtype_package"
rg -q '^  export GGML_NATIVE=OFF$' "$voxtype_package"
rg -q '^  export GGML_AVX512=OFF$' "$voxtype_package"
rg -q "profile\.release\.lto=false" "$voxtype_package"
rg -q -- '--lib --bins --tests' "$voxtype_package"
rg -q 'ln -s /usr/lib/voxtype/voxtype-native "\$pkgdir/usr/bin/voxtype"' "$voxtype_package"
rg -q '/usr/lib/systemd/user/voxtype\.service' "$voxtype_package"
rg -q '/usr/share/voxtype/quickshell/' "$voxtype_package"
! rg -q 'gpu-vulkan|onnx|parakeet|install=' "$voxtype_package"
rg -Fq 'voxtype setup model' pkgbuilds/voxtype-hypxr/README.package.md
rg -Fq 'VOXTYPE_MUSE_API_KEY' pkgbuilds/voxtype-hypxr/README.package.md
for hud_doc in keys-overlay.md cmd-ticker.md battery-wivrn.md; do
  rg -Fq "$hud_doc" pkgbuilds/hypxrhud/PKGBUILD
done

legacy_package=pkgbuilds/hypxrland-legacy-config
[[ $(cd "$legacy_package" && bash -c 'source PKGBUILD; printf "%s-%s" "$pkgver" "$pkgrel"') == "4.0.0-2" ]]
mapfile -t legacy_dependencies < <(
  cd "$legacy_package"
  bash -c 'source PKGBUILD; printf "%s\n" "${depends[@]}"'
)
[[ ${legacy_dependencies[*]} == "hypxrland-omarchy>=1.1.0" ]]
mapfile -t legacy_sources < <(
  cd "$legacy_package"
  bash -c 'source PKGBUILD; printf "%s\n" "${source[@]}"'
)
[[ ${legacy_sources[*]} == "README.md LICENSE" ]]
! rg -q 'basecamp/omarchy|autostart-quattro|default/hypr' "$legacy_package/PKGBUILD"

for package in "${packages[@]}"; do
  [[ $package == "hypxrland-legacy-config" ]] && continue
  if (cd "pkgbuilds/$package" && bash -c 'source PKGBUILD; printf "%s\n" "${depends[@]:-}"') |
    grep -Eq '^hypxrland-legacy-config([<>=].*)?$'; then
    echo "FAIL: $package still depends on hypxrland-legacy-config" >&2
    exit 1
  fi
done

rg -q "'omarchy>=4\.0\.0'" pkgbuilds/hypxrland-omarchy/PKGBUILD
rg -q "'omarchy<4\.1'" pkgbuilds/hypxrland-omarchy/PKGBUILD
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
printf '%s\n' 'user customization' >>"$setup_tmp/config/hypr/hyprland-xr.lua"
HOME="$setup_tmp/home" \
XDG_CONFIG_HOME="$setup_tmp/config" \
HYPXRLAND_OMARCHY_TEMPLATE="$setup_tmp/template" \
  bash pkgbuilds/hypxrland-omarchy/omarchy-setup-hypxrland >/dev/null
[[ $(<"$setup_tmp/config/hypr/hyprland-xr.lua") == $'packaged template\nuser customization' ]]

legacy_tmp="$setup_tmp/legacy"
mkdir -p "$legacy_tmp/config/hypr" "$legacy_tmp/bin"
printf '%s\n' 'legacy customization' >"$legacy_tmp/config/hypr/hyprland-xr.conf"
cat >"$legacy_tmp/bin/uwsm" <<'EOF'
#!/bin/bash
printf '%s\n' "$@"
EOF
chmod 0755 "$legacy_tmp/bin/uwsm"

HOME="$legacy_tmp/home" \
XDG_CONFIG_HOME="$legacy_tmp/config" \
HYPXRLAND_OMARCHY_TEMPLATE="$setup_tmp/template" \
  bash pkgbuilds/hypxrland-omarchy/omarchy-setup-hypxrland >/dev/null
[[ ! -e $legacy_tmp/config/hypr/hyprland-xr.lua ]]
[[ $(<"$legacy_tmp/config/hypr/hyprland-xr.conf") == "legacy customization" ]]

PATH="$legacy_tmp/bin:$PATH" \
HOME="$legacy_tmp/home" \
XDG_CONFIG_HOME="$legacy_tmp/config" \
  bash pkgbuilds/hypxrland/hypxrland-session \
  >"$legacy_tmp/command" 2>"$legacy_tmp/warning"
grep -Fxq "$legacy_tmp/config/hypr/hyprland-xr.conf" "$legacy_tmp/command"
grep -Fq 'legacy hyprland-xr.conf is deprecated' "$legacy_tmp/warning"

printf '%s\n' 'lua customization' >"$legacy_tmp/config/hypr/hyprland-xr.lua"
PATH="$legacy_tmp/bin:$PATH" \
HOME="$legacy_tmp/home" \
XDG_CONFIG_HOME="$legacy_tmp/config" \
  bash pkgbuilds/hypxrland/hypxrland-session \
  >"$legacy_tmp/lua-command" 2>"$legacy_tmp/lua-warning"
grep -Fxq "$legacy_tmp/config/hypr/hyprland-xr.lua" "$legacy_tmp/lua-command"
[[ ! -s $legacy_tmp/lua-warning ]]
[[ $(<"$legacy_tmp/config/hypr/hyprland-xr.lua") == "lua customization" ]]

rg -Fq 'require("hyprland")' pkgbuilds/hypxrland-omarchy/hyprland-xr.lua
rg -Fq 'openxr = {' pkgbuilds/hypxrland-omarchy/hyprland-xr.lua
rg -Fq 'hl.on("hyprland.start"' pkgbuilds/hypxrland-omarchy/hyprland-xr.lua

echo "Package-wave checks passed"
