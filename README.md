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
model and metadata packages. Do not publish aarch64 artifacts until the native
code and runtime behavior have been tested there.

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

The signing key and complete repository tree live only on the publication
host. A complete edge release runs:

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

## Repository host

The host may run Debian, Ubuntu, or Arch:

```bash
bin/setup
```

Signing credentials live outside Git in `/root/.hypxr/build-credentials`:

```bash
export GPG_PRIVATE_KEY='armored operational signing-subkey export'
export GPG_PASSPHRASE='operational signing-subkey passphrase'
export HYPXR_PUBLIC_KEY='armored public certificate'
export HYPXR_PRIMARY_FINGERPRINT='FULL40HEXPRIMARYFINGERPRINT'
export HYPXR_SIGNING_SUBKEY_FINGERPRINT='FULL40HEXSIGNINGSUBKEYFINGERPRINT'
```

Use an offline certification key with a replaceable online signing subkey.
Restrict object-store credentials to the HypXR repository bucket or prefix.
CI may lint and build packages, but it must not receive the signing key.

The recommended storage target is Cloudflare R2 behind a long-lived custom
hostname. See [`docs/cloudflare-r2.md`](docs/cloudflare-r2.md) for the bucket,
rclone, cache, and publication setup. See
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
  --repo-base https://packages.YOUR-DOMAIN \
  --channel edge \
  --output install-hypxr.sh
```

The generated bootstrap verifies the full primary fingerprint, imports it with
`pacman-key`, installs `hypxr-keyring`, and only then adds:

```ini
[hypxr]
SigLevel = PackageRequired DatabaseRequired TrustedOnly
Server = https://packages.example.invalid/stable/$arch
```

The public hostname and signing-key fingerprint remain intentionally unset
until the storage provider and offline key are created. Never publish a
bootstrap script with placeholder trust data.

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
