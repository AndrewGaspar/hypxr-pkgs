#!/bin/bash

set -euo pipefail

ROOT=$(realpath "${BASH_SOURCE[0]%/*}/..")
CANDIDATE_DIR=${1:-$ROOT/build-output/edge/x86_64}
IMAGE=${HYPXR_TEST_IMAGE:-hypxr-pkg-builder:latest-x86_64-edge}
OLD_VERSION=3.8.4-3
OLD_FILENAME="hypxrland-legacy-config-$OLD_VERSION-any.pkg.tar.zst"

mapfile -t candidates < <(
  find "$CANDIDATE_DIR" -maxdepth 1 -type f \
    -name 'hypxrland-legacy-config-*.pkg.tar.zst' -print
)
(( ${#candidates[@]} == 1 )) || {
  echo "Expected one transition package in $CANDIDATE_DIR" >&2
  exit 1
}

candidate=${candidates[0]}
candidate_filename=${candidate##*/}

docker run --rm -i --user root \
  -e TMPDIR=/var/tmp \
  -v "$CANDIDATE_DIR:/packages:ro" \
  -v "$ROOT:/workspace:ro" \
  "$IMAGE" /bin/bash -s -- "/packages/$candidate_filename" "$OLD_FILENAME" <<'CONTAINER'
set -euo pipefail

candidate=$1
old_filename=$2
old_package="/var/tmp/$old_filename"
old_signature="$old_package.sig"
base=https://hypxr.omedora.org/edge/x86_64

curl --fail --silent --show-error "$base/$old_filename" --output "$old_package"
curl --fail --silent --show-error "$base/$old_filename.sig" --output "$old_signature"
gpgv --keyring /workspace/pkgbuilds/hypxr-keyring/hypxr.gpg \
  "$old_signature" "$old_package"

# The detached signature was verified above; the disposable container does not
# enroll the production key in pacman's mutable keyring.
sed -i 's/^LocalFileSigLevel.*/LocalFileSigLevel = Never/' /etc/pacman.conf
pacman -Udd --noconfirm "$old_package"
[[ $(pacman -Q hypxrland-legacy-config) == "hypxrland-legacy-config 3.8.4-3" ]]
[[ -f /usr/share/omarchy/default/hypr/envs.conf ]]
old_payload_count=$(find /usr/share/omarchy/default/hypr -type f -name '*.conf' | wc -l)
(( old_payload_count > 0 ))

config_dir=/home/builder/.config/hypr
mkdir -p "$config_dir"
chown -R builder:builder /home/builder/.config
printf '%s\n' 'custom legacy config' >"$config_dir/hyprland-xr.conf"
chown builder:builder "$config_dir/hyprland-xr.conf"
legacy_sum=$(sha256sum "$config_dir/hyprland-xr.conf" | cut -d' ' -f1)

pacman -Udd --noconfirm "$candidate"
[[ $(pacman -Q hypxrland-legacy-config) == "hypxrland-legacy-config 4.0.0-1" ]]
[[ ! -e /usr/share/omarchy/default/hypr/envs.conf ]]
if [[ -d /usr/share/omarchy/default/hypr ]]; then
  ! find /usr/share/omarchy/default/hypr -type f -name '*.conf' -print -quit | grep -q .
fi
[[ $(sha256sum "$config_dir/hyprland-xr.conf" | cut -d' ' -f1) == "$legacy_sum" ]]
[[ ! -e $config_dir/hyprland-xr.lua ]]
[[ -f /usr/share/doc/hypxrland-legacy-config/README.md ]]

runuser -u builder -- env \
  HOME=/home/builder \
  XDG_CONFIG_HOME=/home/builder/.config \
  HYPXRLAND_OMARCHY_TEMPLATE=/workspace/pkgbuilds/hypxrland-omarchy/hyprland-xr.lua \
  bash /workspace/pkgbuilds/hypxrland-omarchy/omarchy-setup-hypxrland >/dev/null
[[ ! -e $config_dir/hyprland-xr.lua ]]

mock_dir=/var/tmp/hypxr-transition-bin
mkdir -p "$mock_dir"
cat >"$mock_dir/uwsm" <<'EOF'
#!/bin/bash
printf '%s\n' "$@"
EOF
chmod 0755 "$mock_dir/uwsm"
runuser -u builder -- env \
  HOME=/home/builder \
  XDG_CONFIG_HOME=/home/builder/.config \
  PATH="$mock_dir:/usr/bin" \
  bash /workspace/pkgbuilds/hypxrland/hypxrland-session \
  >/var/tmp/legacy-command 2>/var/tmp/legacy-warning
grep -Fxq "$config_dir/hyprland-xr.conf" /var/tmp/legacy-command
grep -Fq 'legacy hyprland-xr.conf is deprecated' /var/tmp/legacy-warning

fresh=/home/fresh
mkdir -p "$fresh/.config"
chown -R builder:builder "$fresh"
runuser -u builder -- env \
  HOME="$fresh" \
  XDG_CONFIG_HOME="$fresh/.config" \
  HYPXRLAND_OMARCHY_TEMPLATE=/workspace/pkgbuilds/hypxrland-omarchy/hyprland-xr.lua \
  bash /workspace/pkgbuilds/hypxrland-omarchy/omarchy-setup-hypxrland >/dev/null
[[ -f $fresh/.config/hypr/hyprland-xr.lua ]]
printf '%s\n' '-- custom lua' >>"$fresh/.config/hypr/hyprland-xr.lua"
lua_sum=$(sha256sum "$fresh/.config/hypr/hyprland-xr.lua" | cut -d' ' -f1)
runuser -u builder -- env \
  HOME="$fresh" \
  XDG_CONFIG_HOME="$fresh/.config" \
  HYPXRLAND_OMARCHY_TEMPLATE=/workspace/pkgbuilds/hypxrland-omarchy/hyprland-xr.lua \
  bash /workspace/pkgbuilds/hypxrland-omarchy/omarchy-setup-hypxrland >/dev/null
[[ $(sha256sum "$fresh/.config/hypr/hyprland-xr.lua" | cut -d' ' -f1) == "$lua_sum" ]]

echo "Legacy transition upgrade checks passed: removed $old_payload_count package-owned configs"
CONTAINER
