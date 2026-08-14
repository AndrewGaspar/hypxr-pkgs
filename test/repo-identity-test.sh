#!/bin/bash

set -euo pipefail

ROOT=$(realpath "${BASH_SOURCE[0]%/*}/..")
cd "$ROOT"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[[ $(git remote get-url upstream 2>/dev/null || true) == "https://github.com/omacom-io/omarchy-pkgs.git" ]] ||
  fail "upstream remote does not track omacom-io/omarchy-pkgs"

if rg -n 'omarchy-build|omarchy\.db|omarchy-pkg-builder|OMARCHY_REPO_HOST|OMARCHY_STATE_DIR|/root/omarchy-pkgs|/root/\.omarchy/build-credentials' \
  bin build helpers systemd .gitignore; then
  fail "found stale Omarchy repository identity"
fi

rg -q 'REPO_DIR="\$BUILD_ROOT/repository/\$MIRROR/\$ARCH"' helpers/paths.sh ||
  fail "published repository path is not HypXR-owned"
rg -q 'REPO_NAME="hypxr"' build/update-repo.sh ||
  fail "repository database is not named hypxr"
rg -q '^\[hypxr-build\]$' build/build.sh ||
  fail "current build-wave repository is missing"
rg -q '^\[hypxr\]$' build/build.sh ||
  fail "published HypXR dependency repository is missing"
rg -q '^\[omarchy\]$' build/build.sh ||
  fail "public Omarchy dependency repository is missing"
rg -q 'pkgs\.omarchy\.org/\$MIRROR/' build/build.sh ||
  fail "Omarchy dependency ring does not follow the HypXR ring"

rg -q 'sign-database' bin/release || fail "release does not sign databases"
rg -q 'hypxr\.db\.tar\.zst\.sig' build/sign-database.sh ||
  fail "database signature is not produced"
rg -q 'PackageRequired DatabaseRequired TrustedOnly' README.md ||
  fail "client signature policy is not documented"
rg -q 'HYPXR_PRIMARY_FINGERPRINT' build/sign.sh ||
  fail "signer does not pin the offline primary fingerprint"
rg -q 'HYPXR_SIGNING_SUBKEY_FINGERPRINT' build/sign.sh ||
  fail "signer does not select an explicit operational signing subkey"
rg -q 'HYPXR_PUBLIC_KEY' build/verify-database.sh ||
  fail "database verification does not use public-only key material"
rg -q 'max-age=31536000, immutable' bin/sync-repo ||
  fail "immutable package cache policy is missing"
rg -q 'no-store, max-age=0, must-revalidate' bin/sync-repo ||
  fail "mutable repository metadata cache policy is missing"
rg -q 'rclone check' bin/sync-repo && rg -q -- '--download --one-way' bin/sync-repo ||
  fail "remote package bytes are not verified before database publication"
rg -q -- '--exclude "\*\.sig"' bin/sync-repo ||
  fail "timestamp-varying signatures are incorrectly byte-compared on repeat publication"
jq -e '
  .repository_hostname == "hypxr.omedora.org" and
  .r2_buckets.published == "packages" and
  .r2_buckets.staging == "packages-staging" and
  .r2_buckets.signing == "packages-signing" and
  .secrets_store_name == "hypxr" and
  (.account_id | test("^[0-9a-f]{32}$")) and
  (.zone_id | test("^[0-9a-f]{32}$")) and
  (.secrets_store_id | test("^[0-9a-f]{32}$"))
' infrastructure/cloudflare.json >/dev/null ||
  fail "tracked Cloudflare resource identity is incomplete"
rg -q 'https://hypxr\.omedora\.org/edge/\$arch' README.md ||
  fail "client repository URL does not use the live Cloudflare hostname"
rg -q 'b56864690db4b781dbf36b94155d808c\.r2\.cloudflarestorage\.com' \
  docs/cloudflare-r2.md || fail "rclone endpoint does not use the live R2 account"
if rg -n 'packages\.hypxr\.dev|packages\.YOUR-DOMAIN|packages\.example\.invalid|ACCOUNT_ID' \
  README.md docs infrastructure; then
  fail "found stale repository-host placeholder"
fi
if rg -n -- '-e (GPG_PRIVATE_KEY|GPG_PASSPHRASE)=' bin; then
  fail "Docker invocation exposes a signing secret in process arguments"
fi
if rg -n -- '--passphrase "\$GPG_PASSPHRASE"' build; then
  fail "GPG invocation exposes the passphrase in process arguments"
fi

if rg -n 'HYPXR_SIGNING_FINGERPRINT' bin build README.md; then
  fail "found obsolete ambiguous signing fingerprint variable"
fi

rg -Fq 'chmod -R a+rwX' helpers/docker-helpers.sh ||
  fail "bind-mounted build directories are not writable by the container user"
if rg -n 'chown -R.*id -u' helpers/docker-helpers.sh; then
  fail "host ownership is incorrectly used for container write access"
fi

for generator in bin/create-keyring-package bin/render-bootstrap; do
  [[ -x $generator ]] || fail "$generator is not executable"
  bash -n "$generator"
done

for release_tool in bin/create-release-manifest bin/verify-release-manifest bin/verify-packages; do
  [[ -x $release_tool ]] || fail "$release_tool is not executable"
  bash -n "$release_tool"
done

rg -q '^    environment: staging$' .github/workflows/packages.yml ||
  fail "package workflow does not isolate staging credentials"
rg -q '^    environment: production$' .github/workflows/packages.yml ||
  fail "package workflow does not use the protected production environment"
if rg -n 'HYPXR_GPG_(PRIVATE_KEY|PASSPHRASE)' .github/workflows/packages.yml |
  rg -v 'secrets\.HYPXR_GPG_'; then
  fail "production signing values are not sourced from environment secrets"
fi

echo "Repository identity checks passed"
