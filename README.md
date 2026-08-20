# HypXR Package Repository

Signed Arch Linux packages for HypXRland and its supporting runtime. The
repository is additive to vanilla Omarchy: stock Hyprland and the ordinary
Omarchy session remain installed as the fallback, while the XR compositor and
its matching `hyprctl` live under `/usr/lib/hypxrland`.

## Relationship to Omarchy

This repository is an upstream-tracking fork of
[`omacom-io/omarchy-pkgs`](https://github.com/omacom-io/omarchy-pkgs). It keeps
the upstream build, dependency-ordering, edge/stable promotion, signing-host,
and publication model. The fork is necessary because the current tooling is
repository-rooted rather than a reusable library.

Keep the original project configured as the `upstream` Git remote. Merge
upstream tooling changes deliberately; do not import its package catalog.

HypXR packages may depend on official Omarchy packages. Arch Linux core and
extra retain their normal repository priority; explicitly named HypXR packages
then resolve from the current build wave, the published HypXR ring, and the
matching public Omarchy ring.

The two local file-backed HypXR repositories deliberately use
`SigLevel = Never` inside the isolated build container. They are mounted from
the trusted build/publication host; remote clients always require signatures.

Vanilla Omarchy already configures and trusts `[omarchy]`. Users add only the
HypXR repository; Omarchy packages are never copied into it.

## Packages

Each package lives under `pkgbuilds/<package>/` and retains the upstream
tooling's `.omarchy/package.json` metadata schema. Locally maintained packages
use:

```json
{
  "source": "local"
}
```

The initial repository is x86_64-only except for architecture-independent
keyring, model, and metadata packages. Do not publish aarch64 artifacts until
the native code and runtime behavior have been tested there.

## Local builds

Docker is the only build-time host requirement:

```bash
bin/repo build --package hypxrpaper hypxrva hypxrhud hypxrvoice-model-base-en
```

The command produces unsigned packages in `build-output/edge/x86_64`. It needs
neither the HypXR signing key nor publication credentials.

Inspect the build plan without Docker or network access:

```bash
bin/repo build --dry-run
```

## Release model

GitHub Actions is the build and operational signing boundary. Every pull request
builds the complete edge package wave and proves the signing path with a
disposable key. Trusted `master` runs upload unsigned packages and a digest
manifest to the private `packages-staging` bucket.

Production publication is a manual workflow dispatch from `master` with the
`publish` input enabled. The `production` GitHub environment must require an
approving reviewer. It exposes only the replaceable operational signing subkey,
its passphrase, and an R2 token restricted to `packages`; the offline primary
and recovery secret keys never enter GitHub or Cloudflare.

The equivalent host-side command remains available for local integration and
recovery. A complete edge release runs:

```bash
bin/repo release --mirror edge
```

That expands to:

```text
build → sign packages → promote → clean → update DB → sign DB → sync
```

Package archives and both repository databases are signed. Publication uploads
package files first, database signatures second, and databases last. A client
that catches the short transition fails closed rather than accepting an
unsigned or inconsistent repository.

Test edge artifacts on real hardware, then promote the exact files to stable:

```bash
bin/repo migrate --package hypxrland-omarchy
```

Large packages may be built away from the signing host and handed to it:

```bash
bin/repo deploy --package hypxrland
```

Configure that host with `HYPXR_REPO_HOST` or `.repo-host`. The default remote
repository is the rclone destination `hypxr:packages`; override it with
`--sync-remote` or `--remote` while provisioning infrastructure.

## GitHub environments

The `staging` environment has:

- `HYPXR_R2_ACCESS_KEY_ID` and `HYPXR_R2_SECRET_ACCESS_KEY`, restricted to
  Object Read & Write on `packages-staging` only.

The reviewer-protected `production` environment will have:

- `HYPXR_GPG_PRIVATE_KEY`: passphrase-protected operational subkey export.
- `HYPXR_GPG_PASSPHRASE`: operational subkey passphrase.
- `HYPXR_R2_PRODUCTION_ACCESS_KEY_ID` and
  `HYPXR_R2_PRODUCTION_SECRET_ACCESS_KEY`, restricted to `packages` only.
- Non-secret variables `HYPXR_PUBLIC_KEY`, `HYPXR_PRIMARY_FINGERPRINT`, and
  `HYPXR_SIGNING_SUBKEY_FINGERPRINT`.

Do not populate production until the disposable workflow passes and the
offline key ceremony is complete. Repository-level secrets must never include
the signing key or production-bucket credentials.

## Repository host

The optional host-side release path may run on Debian, Ubuntu, or Arch:

```bash
bin/setup
```

For local integration tests, signing credentials live outside Git in
`/root/.hypxr/build-credentials`:

```bash
export GPG_PRIVATE_KEY='armored operational signing-subkey export'
export GPG_PASSPHRASE='operational signing-subkey passphrase'
export HYPXR_PUBLIC_KEY='armored public certificate'
export HYPXR_PRIMARY_FINGERPRINT='FULL40HEXPRIMARYFINGERPRINT'
export HYPXR_SIGNING_SUBKEY_FINGERPRINT='FULL40HEXSIGNINGSUBKEYFINGERPRINT'
```

Use an offline certification key with a replaceable operational signing
subkey. Ordinary CI receives only staging credentials and cannot write to the
published bucket. Only an approved production job receives the operational
subkey and public-bucket credentials.

The live storage target is Cloudflare R2 at
[`hypxr.omedora.org`](https://hypxr.omedora.org), with account, zone, bucket,
Secrets Store, and cache-rule identifiers recorded in
[`infrastructure/cloudflare.json`](infrastructure/cloudflare.json). See
[`docs/cloudflare-r2.md`](docs/cloudflare-r2.md) for the publication setup. See
[`docs/github-actions.md`](docs/github-actions.md) for the CI, staging, and
protected publication boundaries. See
[`docs/signing-key.md`](docs/signing-key.md) for the offline key ceremony,
retention model, rotation procedure, and public-file generators.

## Client bootstrap

After the production key ceremony, generate the keyring package and bootstrap
from the public certificate. Both generators reject secret key material,
fingerprint mismatches, placeholder hosts, and non-HTTPS repository URLs:

```bash
bin/create-keyring-package \
  --public-key /secure/transfer/hypxr-public.asc \
  --primary-fingerprint "$HYPXR_PRIMARY_FINGERPRINT"

bin/render-bootstrap \
  --public-key /secure/transfer/hypxr-public.asc \
  --primary-fingerprint "$HYPXR_PRIMARY_FINGERPRINT" \
  --repo-base https://hypxr.omedora.org \
  --channel edge \
  --output install-hypxr.sh
```

The generated bootstrap verifies the full primary fingerprint, imports it with
`pacman-key`, installs `hypxr-keyring`, and only then adds:

```ini
[hypxr]
SigLevel = PackageRequired DatabaseRequired TrustedOnly
Server = https://hypxr.omedora.org/edge/$arch
```

The temporary dogfood trust root is pinned to fingerprint
`74C1F43250AF5125B17FF459644F84BDBE2CAFCE` and expires on November 18, 2026.
Replace it before onboarding users outside the controlled dogfood group. Never
publish a bootstrap script with placeholder trust data.

After bootstrap, the intended one-command install is:

```bash
sudo pacman -Syu hypxrland-omarchy
```

## Upstream maintenance

The fork started from `omacom-io/omarchy-pkgs` commit `aa53101`. To inspect
future tooling changes:

```bash
git fetch upstream
git log --oneline HEAD..upstream/master
```

Keep HypXR identity changes focused. If upstream later exposes generic
repository-name, path, dependency-repository, and signing hooks, the fork can
shrink or move to a cleaner external dependency.
