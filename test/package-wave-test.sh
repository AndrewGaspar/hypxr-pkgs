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
  xreal-ctl
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
  wivrn-hypxr \
  xreal-ctl; do
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
  [hyprpad]=4
  [hypxr-keyring]=8
  [hypxrcompose]=7
  [hypxrhud]=7
  [hypxrland]=1
  [hypxrland-legacy-config]=7
  [hypxrland-omarchy]=8
  [hypxrland-stack]=8
  [hypxrpaper]=8
  [hypxrva]=8
  [hypxrvoice]=7
  [hypxrvoice-model-base-en]=8
  [monado-xreal]=3
  [voxtype-hypxr]=6
  [wivrn-hypxr]=7
  [xreal-ctl]=1
)
for package in "${packages[@]}"; do
  actual_pkgrel=$(cd "pkgbuilds/$package" && bash -c 'source PKGBUILD; printf "%s" "$pkgrel"')
  [[ $actual_pkgrel == "${expected_pkgrel[$package]}" ]]
done

expected_stack_deps=(
  'hypxrland>=0.56.2.r468.g964889899-1'
  'hypxrcompose>=0.20260820.1.gf75ccd4ec-7'
  'hypxrhud>=0.20260816.1.gf96d0e794-7'
  'hypxrpaper>=0.20260704.1.g5cae848cd-8'
  'hypxrva>=0.20260803.1.gbba2c5f8b-8'
  'hypxrvoice>=0.20260812.1.g7ce7d33b2-7'
  'hypxrvoice-model-base-en>=1.0.0-8'
  'wivrn-hypxr>=26.6.2.20260820.1.g3729c7b31-7'
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
[[ $(cd "$legacy_package" && bash -c 'source PKGBUILD; printf "%s-%s" "$pkgver" "$pkgrel"') == "4.0.0-7" ]]
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
rg -q "'omarchy<4\.6'" pkgbuilds/hypxrland-omarchy/PKGBUILD
rg -q "'hypxrland-stack'" pkgbuilds/hypxrland-omarchy/PKGBUILD
rg -q "'monado-xreal: private" pkgbuilds/hypxrland-stack/PKGBUILD
rg -qF '`hypxrland-omarchy` also installs `monado-xreal`' pkgbuilds/hypxrland-stack/README.md

# pacman never installs optdepends, so the XR session hard-depends on the XREAL
# runtime and the 2D/3D helper, at the builds this wave publishes.
mapfile -t session_depends < <(
  cd pkgbuilds/hypxrland-omarchy
  bash -c 'source PKGBUILD; printf "%s\n" "${depends[@]}"'
)
for package in monado-xreal xreal-ctl; do
  wave_version=$(cd "pkgbuilds/$package" && bash -c 'source PKGBUILD; printf "%s-%s" "$pkgver" "$pkgrel"')
  printf '%s\n' "${session_depends[@]}" | grep -Fxq "$package>=$wave_version"
done
session_optdepends=$(cd pkgbuilds/hypxrland-omarchy && bash -c 'source PKGBUILD; printf "%s" "${optdepends[*]:-}"')
[[ -z $session_optdepends ]]
# The socket lives in monado-xreal/, which only the unit creates.
rg -qF -- '-DXRT_IPC_MSG_SOCK_FILENAME=monado-xreal/comp_ipc' pkgbuilds/monado-xreal/PKGBUILD
rg -qx 'RuntimeDirectory=monado-xreal' pkgbuilds/monado-xreal/monado-xreal.service
rg -qx 'RuntimeDirectoryMode=0700' pkgbuilds/monado-xreal/monado-xreal.service
# The tracker's CPU share and oomd preference; user@.service delegates only
# pids, memory and cpu, so an IOWeight= would do nothing.
rg -qx 'CPUWeight=1000' pkgbuilds/monado-xreal/monado-xreal.service
rg -qx 'ManagedOOMPreference=avoid' pkgbuilds/monado-xreal/monado-xreal.service
if rg -q '^IOWeight=' pkgbuilds/monado-xreal/monado-xreal.service; then
  echo "FAIL: monado-xreal.service sets IOWeight=, but io is not delegated" >&2
  exit 1
fi
# omedora#15: out of app.slice (uresourced resets CPUWeight= there on Fedora),
# beside the compositor in session.slice.
(( $(rg -c '^Slice=' pkgbuilds/monado-xreal/monado-xreal.service) == 1 ))
rg -qx 'Slice=session.slice' pkgbuilds/monado-xreal/monado-xreal.service
# The render thread takes a bounded real-time priority from rtkit over sd-bus,
# which XRT_HAVE_SYSTEMD builds in; socket activation and Monado's own unit
# files stay off, and check() proves only the service links libsystemd.
rg -qx 'Environment=XRT_COMPOSITOR_THREAD_REALTIME=true' \
  pkgbuilds/monado-xreal/monado-xreal.service
rg -qxF -- '    -DXRT_HAVE_SYSTEMD=ON \' pkgbuilds/monado-xreal/PKGBUILD
rg -qxF -- '    -DXRT_FEATURE_SERVICE_SYSTEMD=OFF \' pkgbuilds/monado-xreal/PKGBUILD
rg -qxF -- '    -DXRT_INSTALL_SYSTEMD_UNIT_FILES=OFF \' pkgbuilds/monado-xreal/PKGBUILD
monado_check=$(sed -n '/^check() {/,/^}/p' pkgbuilds/monado-xreal/PKGBUILD)
grep -qxF "  grep -q '^XRT_HAVE_SYSTEMD:BOOL=ON\$' build/CMakeCache.txt" <<<"$monado_check"
grep -qxF "  grep -qx 'Environment=XRT_COMPOSITOR_THREAD_REALTIME=true' monado-xreal.service" \
  <<<"$monado_check"
grep -qxF '  needed=$(readelf -d build/src/xrt/targets/service/monado-service)' <<<"$monado_check"
grep -qxF "  [[ \$needed == *'Shared library: [libsystemd.so.0]'* ]]" <<<"$monado_check"
grep -qxF '  needed=$(readelf -d build/src/xrt/targets/openxr/libopenxr_monado_xreal.so)' \
  <<<"$monado_check"
grep -qxF "  [[ \$needed != *'[libsystemd.so'* ]]" <<<"$monado_check"

# Every local source file matches the checksum its PKGBUILD pins.
for package in "${packages[@]}"; do
  while IFS=$'\t' read -r algorithm file sum; do
    [[ $sum == "SKIP" ]] && continue
    if [[ $("${algorithm}sum" "pkgbuilds/$package/$file" | cut -d' ' -f1) != "$sum" ]]; then
      echo "FAIL: $package/$file does not match its ${algorithm}sums entry" >&2
      exit 1
    fi
  done < <(
    cd "pkgbuilds/$package"
    bash -c '
      source PKGBUILD
      if (( ${#sha512sums[@]} )); then
        algorithm=sha512
        sums=("${sha512sums[@]}")
      else
        algorithm=sha256
        sums=("${sha256sums[@]}")
      fi
      for ((i = 0; i < ${#source[@]}; i++)); do
        [[ ${source[i]} == *://* ]] && continue
        printf "%s\t%s\t%s\n" "$algorithm" "${source[i]}" "${sums[i]}"
      done
    '
  )
done

# No Arch or Omarchy repository ships uaccess rules for XREAL glasses
# (xr-hardware is AUR-only), so monado-xreal's rule must cover every model
# xreal-ctl and the runtime drive, the hidraw nodes included.
xreal_rules=pkgbuilds/monado-xreal/71-hypxr-xreal.rules
[[ ! -e pkgbuilds/monado-xreal/71-hypxr-xreal-ultra.rules ]]
for product in 0424 0426 0428 0432; do
  rg -qxF "ATTRS{idVendor}==\"3318\", ATTRS{idProduct}==\"$product\", TAG+=\"uaccess\", ENV{ID_xrhardware}=\"1\"" \
    "$xreal_rules"
done
(( $(rg -c '^ATTRS' "$xreal_rules") == 4 ))
rg -qF '/usr/lib/udev/rules.d/71-hypxr-xreal.rules' pkgbuilds/monado-xreal/PKGBUILD

# xreal-ctl builds contrib/xreal from the archive hypxrland already pins, so a
# hypxrland bump must carry it along: same commit, same file name, same sha.
pkgbuild_value() { # <package> <expression>
  (cd "pkgbuilds/$1" && bash -c "source PKGBUILD; printf '%s\n' $2")
}
xreal_commit=$(pkgbuild_value xreal-ctl '"$_commit"')
[[ -n $xreal_commit && $xreal_commit == "$(pkgbuild_value hypxrland '"$_commit"')" ]]
[[ $(pkgbuild_value xreal-ctl '"${source[0]}"') == "$(pkgbuild_value hypxrland '"${source[0]}"')" ]]
[[ $(pkgbuild_value xreal-ctl '"${sha256sums[0]}"') == "$(pkgbuild_value hypxrland '"${sha256sums[0]}"')" ]]
(( $(pkgbuild_value xreal-ctl '"${#source[@]}"') == 1 ))
[[ $(pkgbuild_value xreal-ctl '"$pkgver"') == "0.20261105.1.g${xreal_commit:0:9}" ]]
[[ $(pkgbuild_value xreal-ctl '"$url"') == "$(pkgbuild_value hypxrland '"$url"')" ]]
mapfile -t xreal_depends < <(pkgbuild_value xreal-ctl '"${depends[@]}"')
[[ ${xreal_depends[*]} == "glibc hidapi" ]]
rg -qF 'make -C "Hyprland-$_commit/contrib/xreal"' pkgbuilds/xreal-ctl/PKGBUILD
rg -qF '$LDFLAGS' pkgbuilds/xreal-ctl/PKGBUILD
rg -qF '"$pkgdir/usr/bin/xreal-ctl"' pkgbuilds/xreal-ctl/PKGBUILD
rg -qF 'usage: xreal-ctl mode 2d|3d' pkgbuilds/xreal-ctl/PKGBUILD
rg -qF '"$ctl" detect' pkgbuilds/xreal-ctl/PKGBUILD
rg -qF "Is monado-xreal (its udev rules) installed?" pkgbuilds/xreal-ctl/PKGBUILD

# makepkg's errexit ignores a `! cmd` line, so such a check can never fail.
no_bare_negation_in_check() { # <package>
  if sed -n '/^check() {/,/^}/p' "pkgbuilds/$1/PKGBUILD" | grep -qE '^[[:space:]]*! '; then
    echo "FAIL: $1 check() has a bare negated command, which never fails the build" >&2
    exit 1
  fi
}
no_bare_negation_in_check xreal-ctl
no_bare_negation_in_check monado-xreal
sed -n '/^check() {/,/^}/p' pkgbuilds/monado-xreal/PKGBUILD |
  grep -qxF '  caps=$(getcap build/src/xrt/targets/service/monado-service)'
sed -n '/^check() {/,/^}/p' pkgbuilds/monado-xreal/PKGBUILD |
  grep -qxF '  [[ -z $caps ]]'

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

# The power profile is monado-xreal's business (below); the XR session starts
# nothing of its own.
[[ ! -e pkgbuilds/hypxrland-omarchy/performance-hold ]]
if rg -qi 'performance.hold|PERFORMANCE_HOLD|power-saver|setsid|python' \
  pkgbuilds/hypxrland-omarchy/omarchy-xr-session pkgbuilds/hypxrland-omarchy/PKGBUILD; then
  echo "FAIL: the XR session must not handle the power profile itself" >&2
  exit 1
fi
rg -qF 'systemctl --user mask monado-xreal-avoid-power-saver.service' \
  pkgbuilds/hypxrland-stack/README.md

# monado-xreal keeps the runtime off power-saver while it runs (omedora#14), a
# stopgap until Monado runs well without turbo: the runtime pulls the unit in
# with Wants=, and the unit is a oneshot bound to the runtime, so its
# ExecStop= restores the profile however the runtime ends.
runtime_unit=pkgbuilds/monado-xreal/monado-xreal.service
avoid_unit=pkgbuilds/monado-xreal/monado-xreal-avoid-power-saver.service
avoid_helper=pkgbuilds/monado-xreal/avoid-power-saver
rg -qx 'Wants=monado-xreal-avoid-power-saver.service' "$runtime_unit"
if rg -q '^(Requires|Requisite|BindsTo|After|Upholds)=.*avoid-power-saver' "$runtime_unit"; then
  echo "FAIL: monado-xreal.service must never depend on or wait for the unit" >&2
  exit 1
fi
(( $(grep -v '^#' "$runtime_unit" | grep -c 'avoid-power-saver') == 1 ))
rg -qx 'BindsTo=monado-xreal.service' "$avoid_unit"
rg -qx 'After=monado-xreal.service' "$avoid_unit"
rg -qx 'Type=oneshot' "$avoid_unit"
rg -qx 'RemainAfterExit=yes' "$avoid_unit"
rg -qx 'RuntimeDirectory=monado-xreal-avoid-power-saver' "$avoid_unit"
rg -qx 'ExecStart=/usr/lib/monado-xreal/avoid-power-saver enter' "$avoid_unit"
rg -qx 'ExecStop=/usr/lib/monado-xreal/avoid-power-saver leave' "$avoid_unit"
if rg -q '^\[Install\]' "$avoid_unit"; then
  echo "FAIL: the power-saver unit has no [Install]; only the runtime pulls it in" >&2
  exit 1
fi
[[ -x $avoid_helper ]]
[[ $(head -1 "$avoid_helper") == "#!/bin/bash" ]]
if [[ -e pkgbuilds/monado-xreal/performance-hold \
  || -e pkgbuilds/monado-xreal/monado-xreal-performance-hold.service ]] \
  || rg -q 'performance-hold|python-gobject' pkgbuilds/monado-xreal/PKGBUILD; then
  echo "FAIL: monado-xreal no longer ships the performance hold" >&2
  exit 1
fi
mapfile -t runtime_depends < <(
  cd pkgbuilds/monado-xreal
  bash -c 'source PKGBUILD; printf "%s\n" "${depends[@]}"'
)
# busctl, which the helper uses, is in systemd.
printf '%s\n' "${runtime_depends[@]}" | grep -Fxq systemd
# The render thread's real-time priority comes from rtkit, over sd-bus.
printf '%s\n' "${runtime_depends[@]}" | grep -Fxq rtkit
printf '%s\n' "${runtime_depends[@]}" | grep -Fxq systemd-libs
if printf '%s\n' "${runtime_depends[@]}" | grep -Fxq -e python -e python-gobject; then
  echo "FAIL: monado-xreal no longer needs python or python-gobject at run time" >&2
  exit 1
fi
rg -qF '"$pkgdir/usr/lib/systemd/user/monado-xreal-avoid-power-saver.service"' \
  pkgbuilds/monado-xreal/PKGBUILD
rg -qF '"$pkgdir/usr/lib/monado-xreal/avoid-power-saver"' pkgbuilds/monado-xreal/PKGBUILD

# The helper itself, against a stub busctl standing in for power-profiles-daemon:
# enter switches only power-saver to balanced; leave restores power-saver only
# when enter switched and the profile is still balanced; failures log, exit 0.
avoid_tmp="$setup_tmp/avoid-power-saver"
mkdir -p "$avoid_tmp/bin" "$avoid_tmp/rt" "$avoid_tmp/pp"
cat >"$avoid_tmp/bin/busctl" <<'EOF_BUSCTL'
#!/bin/bash
d=$FAKE_PP
args=()
for a in "$@"; do
  [[ $a == --system || $a == --timeout=* ]] || args+=("$a")
done
[[ ${args[1]} == org.freedesktop.UPower.PowerProfiles ]] || exit 1
if [[ -e $d/no-daemon ]]; then
  echo "Could not activate remote peer" >&2
  exit 1
fi
case ${args[0]}:${args[4]} in
  get-property:ActiveProfile) echo "s \"$(<"$d/active")\"" ;;
  get-property:ActiveProfileHolds) cat "$d/holds" ;;
  set-property:ActiveProfile)
    if [[ -e $d/refuse ]]; then echo "Unauthorized" >&2; exit 1; fi
    printf '%s\n' "${args[6]}" >"$d/active"
    echo set >>"$d/sets" ;;
  *) exit 1 ;;
esac
EOF_BUSCTL
chmod 0755 "$avoid_tmp/bin/busctl"
export FAKE_PP="$avoid_tmp/pp"
avoid_reset() { # <profile>
  rm -f "$FAKE_PP"/* "$avoid_tmp/rt"/*
  printf '%s\n' "$1" >"$FAKE_PP/active"
  echo 'aa{sv} 0' >"$FAKE_PP/holds"
  : >"$FAKE_PP/sets"
}
avoid_run() { # <step>
  PATH="$avoid_tmp/bin:$PATH" RUNTIME_DIRECTORY="$avoid_tmp/rt" \
    timeout 20 "$avoid_helper" "$1" 2>/dev/null
}
avoid_state() { printf '%s:%s' "$(<"$FAKE_PP/active")" "$(wc -l <"$FAKE_PP/sets")"; }

avoid_status=0
avoid_run hold || avoid_status=$?
(( avoid_status == 2 ))
avoid_reset power-saver
avoid_run enter
[[ $(avoid_state) == balanced:1 && -e $avoid_tmp/rt/switched-to-balanced ]]
avoid_run leave
[[ $(avoid_state) == power-saver:2 && ! -e $avoid_tmp/rt/switched-to-balanced ]]
for profile in balanced performance; do
  avoid_reset "$profile"
  avoid_run enter
  avoid_run leave
  [[ $(avoid_state) == "$profile:0" ]]
done
avoid_reset power-saver
avoid_run enter
echo performance >"$FAKE_PP/active"
avoid_run leave
[[ $(avoid_state) == performance:1 ]]
avoid_reset power-saver
echo 'aa{sv} 1 3 "Profile" s "power-saver" "Reason" s "low battery" "ApplicationId" s "x"' >"$FAKE_PP/holds"
avoid_run enter
[[ $(avoid_state) == power-saver:0 ]]
avoid_reset power-saver
: >"$FAKE_PP/refuse"
avoid_run enter
[[ $(avoid_state) == power-saver:0 && ! -e $avoid_tmp/rt/switched-to-balanced ]]
avoid_reset power-saver
: >"$FAKE_PP/no-daemon"
avoid_run enter
avoid_reset power-saver
avoid_run enter
: >"$FAKE_PP/no-daemon"
avoid_run leave
avoid_reset power-saver
PATH="$avoid_tmp/bin:$PATH" RUNTIME_DIRECTORY= "$avoid_helper" enter 2>/dev/null
[[ $(avoid_state) == power-saver:0 ]]
avoid_output=$(RUNTIME_DIRECTORY="$avoid_tmp/rt" \
  DBUS_SYSTEM_BUS_ADDRESS="unix:path=$setup_tmp/no-such-bus" \
  timeout 20 "$avoid_helper" enter 2>&1)
[[ $avoid_output == *"cannot read the active power profile"* ]]
unset FAKE_PP
no_bare_negation_in_check monado-xreal

echo "Package-wave checks passed"
