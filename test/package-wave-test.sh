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
  [hyprpad]=1
  [hypxr-keyring]=5
  [hypxrcompose]=4
  [hypxrhud]=4
  [hypxrland]=1
  [hypxrland-legacy-config]=4
  [hypxrland-omarchy]=5
  [hypxrland-stack]=6
  [hypxrpaper]=5
  [hypxrva]=5
  [hypxrvoice]=4
  [hypxrvoice-model-base-en]=5
  [monado-xreal]=3
  [voxtype-hypxr]=3
  [wivrn-hypxr]=4
  [xreal-ctl]=1
)
for package in "${packages[@]}"; do
  actual_pkgrel=$(cd "pkgbuilds/$package" && bash -c 'source PKGBUILD; printf "%s" "$pkgrel"')
  [[ $actual_pkgrel == "${expected_pkgrel[$package]}" ]]
done

expected_stack_deps=(
  'hypxrland>=0.56.2.r434.g9097b3c02-1'
  'hypxrcompose>=0.20260820.1.gf75ccd4ec-4'
  'hypxrhud>=0.20260816.1.gf96d0e794-4'
  'hypxrpaper>=0.20260704.1.g5cae848cd-5'
  'hypxrva>=0.20260803.1.gbba2c5f8b-5'
  'hypxrvoice>=0.20260812.1.g7ce7d33b2-4'
  'hypxrvoice-model-base-en>=1.0.0-5'
  'wivrn-hypxr>=26.6.2.20260820.1.g3729c7b31-4'
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
[[ $(cd "$legacy_package" && bash -c 'source PKGBUILD; printf "%s-%s" "$pkgver" "$pkgrel"') == "4.0.0-4" ]]
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
[[ $(pkgbuild_value xreal-ctl '"$pkgver"') == "0.20261016.1.g${xreal_commit:0:9}" ]]
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

# The XR session holds the performance power profile (omedora#12). The wrapper
# runs from a copy whose /usr paths point at stubs, so this needs no XR stack,
# power-profiles-daemon or system bus.
session_wrapper=pkgbuilds/hypxrland-omarchy/omarchy-xr-session
performance_hold=pkgbuilds/hypxrland-omarchy/performance-hold
omarchy_package=pkgbuilds/hypxrland-omarchy/PKGBUILD
hold_tmp="$setup_tmp/hold"
mkdir -p "$hold_tmp/home/.config/hypr"
: >"$hold_tmp/home/.config/hypr/hyprland-xr.lua"
cat >"$hold_tmp/session" <<EOF
#!/bin/bash
echo "\$\$" >"$hold_tmp/session.pid"
echo "\$*" >"$hold_tmp/session.args"
EOF
cat >"$hold_tmp/hold-ok" <<EOF
#!/bin/bash
echo "\$*" >"$hold_tmp/hold.args"
EOF
cat >"$hold_tmp/hold-fails" <<EOF
#!/bin/bash
echo "\$*" >"$hold_tmp/hold.args"
exit 1
EOF
chmod 0755 "$hold_tmp/session" "$hold_tmp/hold-ok" "$hold_tmp/hold-fails"

stub_session_wrapper() { # <helper path>
  sed -e "s|/usr/bin/hypxrland-session|$hold_tmp/session|" \
    -e "s|/usr/bin/omarchy-setup-hypxrland|false|" \
    -e "s|/usr/lib/hypxrland-omarchy/performance-hold|$1|" \
    "$session_wrapper" >"$hold_tmp/wrapper"
  chmod 0755 "$hold_tmp/wrapper"
}
run_session_wrapper() { # [env assignments...]
  rm -f "$hold_tmp/session.pid" "$hold_tmp/session.args" "$hold_tmp/hold.args"
  env -u HYPXRLAND_PERFORMANCE_HOLD HOME="$hold_tmp/home" XDG_CONFIG_HOME= "$@" \
    "$hold_tmp/wrapper" --flag value
}
wait_for_file() { # <path>
  local tries
  for ((tries = 0; tries < 50; tries++)); do
    [[ -s $1 ]] && return 0
    sleep 0.1
  done
  return 1
}

rg -qxF '  setsid -f /usr/lib/hypxrland-omarchy/performance-hold "$$" </dev/null || true' \
  "$session_wrapper"

stub_session_wrapper "$hold_tmp/hold-ok"
run_session_wrapper
wait_for_file "$hold_tmp/hold.args"
# The helper watches the PID the session keeps after its execs.
[[ $(<"$hold_tmp/hold.args") == "$(<"$hold_tmp/session.pid")" ]]
[[ $(<"$hold_tmp/session.args") == "--flag value" ]]

run_session_wrapper HYPXRLAND_PERFORMANCE_HOLD=0
[[ -s $hold_tmp/session.pid ]]
sleep 0.5
[[ ! -e $hold_tmp/hold.args ]]

run_session_wrapper HYPXRLAND_PERFORMANCE_HOLD=1
wait_for_file "$hold_tmp/hold.args"

# A failing or missing helper never stops the session.
stub_session_wrapper "$hold_tmp/hold-fails"
run_session_wrapper
[[ -s $hold_tmp/session.pid ]]
stub_session_wrapper "$hold_tmp/does-not-exist"
run_session_wrapper 2>/dev/null
[[ -s $hold_tmp/session.pid ]]

# The helper fails open, with or without PyGObject installed: no daemon on the
# bus, or a session that is already gone, is logged and exits 0.
hold_status=0
python3 -I "$performance_hold" >/dev/null 2>&1 || hold_status=$?
(( hold_status == 2 ))
sleep 2 &
hold_sleeper=$!
hold_status=0
hold_output=$(DBUS_SYSTEM_BUS_ADDRESS="unix:path=$hold_tmp/no-such-bus" \
  timeout 20 python3 -I "$performance_hold" "$hold_sleeper" 2>&1) || hold_status=$?
(( hold_status == 0 ))
[[ $hold_output == *"not holding"* ]]
wait "$hold_sleeper" || true
hold_status=0
hold_output=$(python3 -I "$performance_hold" "$hold_sleeper" 2>&1) || hold_status=$?
(( hold_status == 0 ))
[[ $hold_output == *"cannot watch the session process"* ]]

# The helper's contract with power-profiles-daemon, and its packaging.
rg -qF '"HoldProfile"' "$performance_hold"
rg -qF '"ReleaseProfile"' "$performance_hold"
rg -qxF 'BUS_NAME = "org.freedesktop.UPower.PowerProfiles"' "$performance_hold"
rg -qxF 'PROFILE = "performance"' "$performance_hold"
rg -qF 'os.pidfd_open(pid)' "$performance_hold"
mapfile -t session_depends < <(
  cd pkgbuilds/hypxrland-omarchy
  bash -c 'source PKGBUILD; printf "%s\n" "${depends[@]}"'
)
for dependency in python python-gobject util-linux; do
  printf '%s\n' "${session_depends[@]}" | grep -Fxq "$dependency"
done
rg -qF '"$pkgdir/usr/lib/hypxrland-omarchy/performance-hold"' "$omarchy_package"
rg -qF 'HYPXRLAND_PERFORMANCE_HOLD=0' pkgbuilds/hypxrland-stack/README.md
no_bare_negation_in_check hypxrland-omarchy

# monado-xreal holds the performance power profile while the runtime runs
# (omedora#12), a stopgap until Monado runs well without turbo: the runtime
# pulls the hold unit in with Wants=, and the hold is bound to the runtime.
runtime_unit=pkgbuilds/monado-xreal/monado-xreal.service
hold_unit=pkgbuilds/monado-xreal/monado-xreal-performance-hold.service
hold_helper=pkgbuilds/monado-xreal/performance-hold
rg -qx 'Wants=monado-xreal-performance-hold.service' "$runtime_unit"
if rg -q '^(Requires|Requisite|BindsTo|After|Upholds)=.*performance-hold' "$runtime_unit"; then
  echo "FAIL: monado-xreal.service must never depend on or wait for the hold" >&2
  exit 1
fi
(( $(grep -v '^#' "$runtime_unit" | grep -c 'performance-hold') == 1 ))
rg -qx 'BindsTo=monado-xreal.service' "$hold_unit"
rg -qx 'After=monado-xreal.service' "$hold_unit"
rg -qx 'Type=simple' "$hold_unit"
rg -qx 'Restart=no' "$hold_unit"
rg -qx 'ExecStart=/usr/lib/monado-xreal/performance-hold' "$hold_unit"
if rg -q '^\[Install\]' "$hold_unit"; then
  echo "FAIL: the hold unit has no [Install]; only the runtime pulls it in" >&2
  exit 1
fi
[[ -x $hold_helper ]]
rg -qF '"HoldProfile"' "$hold_helper"
rg -qF '"ReleaseProfile"' "$hold_helper"
rg -qxF 'BUS_NAME = "org.freedesktop.UPower.PowerProfiles"' "$hold_helper"
rg -qxF 'PROFILE = "performance"' "$hold_helper"
rg -qxF 'APP_ID = "monado-xreal"' "$hold_helper"
rg -qxF 'REASON = "XREAL runtime running"' "$hold_helper"
if rg -q 'pidfd|argv\[1\]' "$hold_helper"; then
  echo "FAIL: the hold helper has no PID-watching mode left" >&2
  exit 1
fi
mapfile -t runtime_depends < <(
  cd pkgbuilds/monado-xreal
  bash -c 'source PKGBUILD; printf "%s\n" "${depends[@]}"'
)
for dependency in python python-gobject; do
  printf '%s\n' "${runtime_depends[@]}" | grep -Fxq "$dependency"
done
rg -qF '"$pkgdir/usr/lib/systemd/user/monado-xreal-performance-hold.service"' \
  pkgbuilds/monado-xreal/PKGBUILD
rg -qF '"$pkgdir/usr/lib/monado-xreal/performance-hold"' pkgbuilds/monado-xreal/PKGBUILD

# The helper itself: usage, then against a fake power-profiles-daemon on a
# private bus it must hold until SIGTERM or SIGINT, release, and exit 0, and it
# must fail open (log, exit 0) on a refused hold or with no bus.
hold_status=0
python3 -I "$hold_helper" extra >/dev/null 2>&1 || hold_status=$?
(( hold_status == 2 ))
if python3 -I -c 'from gi.repository import Gio' 2>/dev/null && command -v dbus-daemon >/dev/null; then
  live_tmp="$setup_tmp/runtime-hold"
  mkdir -p "$live_tmp"
  cat >"$live_tmp/fake-daemon.py" <<'EOF_DAEMON'
import os
import sys
from gi.repository import Gio, GLib

LOG = sys.argv[1]
XML = """<node><interface name="org.freedesktop.UPower.PowerProfiles">
<method name="HoldProfile"><arg type="s" direction="in"/><arg type="s" direction="in"/>
<arg type="s" direction="in"/><arg type="u" direction="out"/></method>
<method name="ReleaseProfile"><arg type="u" direction="in"/></method>
</interface></node>"""


def record(line):
    with open(LOG, "a") as log:
        log.write(line + "\n")


def on_call(conn, sender, path, iface, method, params, invocation):
    if method == "HoldProfile":
        if os.path.exists(LOG + ".refuse"):
            invocation.return_dbus_error("org.freedesktop.DBus.Error.AccessDenied", "refused")
            return
        record("hold " + "|".join(params.unpack()))
        invocation.return_value(GLib.Variant("(u)", (7,)))
    else:
        record("release %d" % params.unpack()[0])
        invocation.return_value(None)


def on_bus(conn, name):
    info = Gio.DBusNodeInfo.new_for_xml(XML).interfaces[0]
    conn.register_object("/org/freedesktop/UPower/PowerProfiles", info, on_call, None, None)


Gio.bus_own_name(Gio.BusType.SYSTEM, "org.freedesktop.UPower.PowerProfiles",
                 Gio.BusNameOwnerFlags.NONE, on_bus, lambda *a: record("ready"), None)
GLib.MainLoop().run()
EOF_DAEMON
  live_log="$live_tmp/daemon.log"
  dbus-daemon --session --nofork --address="unix:path=$live_tmp/bus" >/dev/null 2>&1 &
  live_bus=$!
  for ((tries = 0; tries < 50; tries++)); do
    [[ -S $live_tmp/bus ]] && break
    sleep 0.1
  done
  DBUS_SYSTEM_BUS_ADDRESS="unix:path=$live_tmp/bus" \
    python3 -I -W ignore::DeprecationWarning "$live_tmp/fake-daemon.py" "$live_log" &
  live_daemon=$!
  trap 'kill "$live_daemon" "$live_bus" 2>/dev/null || true; rm -rf "$setup_tmp"' EXIT
  wait_for_log_line() { # <line>
    local tries
    for ((tries = 0; tries < 100; tries++)); do
      grep -qxF -- "$1" "$live_log" 2>/dev/null && return 0
      sleep 0.1
    done
    return 1
  }
  wait_for_log_line ready
  for stop_signal in TERM INT; do
    : >"$live_log"
    DBUS_SYSTEM_BUS_ADDRESS="unix:path=$live_tmp/bus" \
      python3 -I "$hold_helper" 2>"$live_tmp/hold.err" &
    hold_pid=$!
    wait_for_log_line 'hold performance|XREAL runtime running|monado-xreal'
    sleep 0.5
    kill -0 "$hold_pid"
    (( $(grep -c '^release' "$live_log") == 0 ))
    kill "-$stop_signal" "$hold_pid"
    timeout 20 tail --pid="$hold_pid" -f /dev/null
    hold_status=0
    wait "$hold_pid" || hold_status=$?
    (( hold_status == 0 ))
    wait_for_log_line 'release 7'
    grep -qF "released 'performance'" "$live_tmp/hold.err"
  done
  : >"$live_log.refuse"
  hold_status=0
  hold_output=$(DBUS_SYSTEM_BUS_ADDRESS="unix:path=$live_tmp/bus" \
    timeout 20 python3 -I "$hold_helper" 2>&1) || hold_status=$?
  rm -f "$live_log.refuse"
  (( hold_status == 0 ))
  [[ $hold_output == *"AccessDenied: refused"* ]]
  kill "$live_daemon" "$live_bus" 2>/dev/null || true
elif [[ -n ${CI:-} ]]; then
  echo "FAIL: the runtime-hold checks need PyGObject and dbus-daemon in CI" >&2
  exit 1
else
  echo "SKIP: live runtime-hold checks need PyGObject and dbus-daemon" >&2
fi
hold_status=0
hold_output=$(DBUS_SYSTEM_BUS_ADDRESS="unix:path=$setup_tmp/no-such-bus" \
  timeout 20 python3 -I "$hold_helper" 2>&1) || hold_status=$?
(( hold_status == 0 ))
[[ $hold_output == *"not holding"* ]]
no_bare_negation_in_check monado-xreal

echo "Package-wave checks passed"
