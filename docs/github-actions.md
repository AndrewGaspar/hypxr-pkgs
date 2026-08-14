# GitHub Actions publication boundary

GitHub Actions builds, validates, signs, and publishes the HypXR repository.
The workflow separates untrusted package execution, staging credentials, and
production signing into different jobs and environments.

## Build and disposable signing

Pull requests and trusted `master` changes build all packages declared for the
edge mirror. The build job creates an immutable workflow artifact containing
unsigned package archives and `release-manifest.json`. The manifest records the
repository, source commit, workflow identity, package metadata, byte length,
and SHA-256 for every package, and rejects an incomplete package wave.

A separate job downloads that artifact, creates a disposable certification key
and signing subkey, and exercises the complete signing path:

```text
sign packages -> verify packages -> promote -> create databases
  -> sign databases -> verify databases -> verify packages again
```

It also proves that tampered package content fails verification. Disposable
keys, signatures, and databases are discarded and never uploaded to R2.

## Staging

Only runs from `master` can use the `staging` environment. Its R2 token has
Object Read & Write permission on `packages-staging` and no other bucket.
Unsigned packages upload beneath an immutable run-specific prefix:

```text
incoming/github/<owner>/<repository>/<commit>/<run>-<attempt>/edge/x86_64/
```

Packages upload first and the manifest uploads last as the completion marker.
Pull requests never receive staging credentials.

## Production

Production publication requires a manual workflow dispatch from `master` with
the `publish` input enabled. The `production` environment must:

- Require an approving reviewer.
- Restrict deployment to `master`.
- Store only the operational signing-subkey export and passphrase, never the
  offline primary or recovery secret key.
- Store an R2 token scoped only to the public `packages` bucket.
- Hold the public certificate and exact primary and signing-subkey fingerprints
  as non-secret variables.

The job signs and independently verifies every package, creates and verifies
both repository databases, then uses the existing fail-closed sync order:
immutable packages and signatures first, database signatures second, and
databases last. Existing versioned package names are never overwritten.

The signing subkey is replaceable and expires annually. GitHub is not an HSM:
any administrator able to change environment protection, Actions secrets, or a
reviewed workflow is part of the operational signing boundary. Branch rules,
review of workflow changes, and the offline recovery material remain essential.

## Required configuration

The `staging` environment secrets are:

```text
HYPXR_R2_ACCESS_KEY_ID
HYPXR_R2_SECRET_ACCESS_KEY
```

After the offline ceremony, the protected `production` environment receives:

```text
HYPXR_GPG_PRIVATE_KEY
HYPXR_GPG_PASSPHRASE
HYPXR_R2_PRODUCTION_ACCESS_KEY_ID
HYPXR_R2_PRODUCTION_SECRET_ACCESS_KEY
```

Its non-secret variables are:

```text
HYPXR_PUBLIC_KEY
HYPXR_PRIMARY_FINGERPRINT
HYPXR_SIGNING_SUBKEY_FINGERPRINT
```

Do not enable publication until a disposable workflow run succeeds and the
production environment protections are independently reviewed.
