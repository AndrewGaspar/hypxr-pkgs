# Cloudflare signing boundary

The production goal is to keep the operational package-signing subkey inside
Cloudflare. This is a target architecture, not a deployed service yet. The
`hypxr` Secrets Store exists but remains empty until a disposable-key prototype
passes review.

## Why a Container is required

A Worker can resolve a Secrets Store binding but cannot execute GnuPG. The
signer therefore uses a private queue consumer to control a singleton
Cloudflare Container. The Container has no public route, no default port, no
SSH, no Internet access, and executes only a fixed signing program without a
shell or caller-controlled arguments.

Secrets Store is not an HSM. The Worker receives plaintext secret values, so
any identity able to deploy secret-bound signer code is part of the signing
trust boundary. Signer deployment is manual from reviewed commits and is never
granted to ordinary package CI.

## Storage boundary

```text
package CI
  -> packages-staging (CI can write; private)
  -> reviewed release manifest
  -> signer queue
  -> packages-signing/sha256/<digest> (signer-only frozen input)
  -> packages (signer-only published output)
```

The release manifest contains the canonical object key, byte length, SHA-256,
package identity, channel, architecture, source commit, and workflow identity.
The signer copies a matching staging object to the digest-addressed frozen
bucket before signing, then signs and verifies a fresh read from that frozen
copy. It derives every destination path itself and rejects attempts to replace
an existing versioned filename with different bytes.

Package archives and signatures publish first. Repository database signatures
publish next and the databases publish last. This preserves the existing
fail-closed update order.

## Secrets and configuration

The `hypxr` Secrets Store will hold only:

- `HYPXR_GPG_PRIVATE_KEY`: passphrase-protected export of the operational
  signing subkey, never the offline primary or recovery subkey.
- `HYPXR_GPG_PASSPHRASE`: the operational subkey passphrase.

The full primary and signing-subkey fingerprints and public certificate are
non-secret, reviewed repository configuration. The signer reconstructs an
ephemeral `GNUPGHOME`, imports the operational export, and requires both exact
fingerprints before signing. It passes the passphrase through a file descriptor
and never logs secrets, environment variables, command lines, or package
contents.

## Rollout gates

1. Build a disposable-key Worker/Container prototype with explicit
   `workers_dev = false`, `preview_urls = false`, one Container instance,
   `enableInternet = false`, and SSH disabled.
2. Stream and sign the current 133 MB model package and a 1 GiB synthetic
   object without buffering them through Worker memory.
3. Prove manifest validation, frozen-copy integrity, conditional publication,
   retry idempotency, and independent signature verification.
4. Add an authenticated human release gate. CI receives no queue credential,
   production-bucket credential, Worker deployment permission, or Secrets
   Store permission.
5. Perform the offline primary/subkey ceremony, measure the exact operational
   export against the Secrets Store value limit, and populate the two values
   interactively.
6. Shadow-publish into a private test bucket and verify every package and
   database signature using only the checked-in public certificate.
7. Make the signer the sole writer to `packages`, publish edge, test on XR
   hardware, and promote the exact verified artifacts to stable.

Until these gates pass, the external host workflow remains available for local
integration testing and initial bring-up. It must use a bucket-scoped R2 token
and a root-owned `0600` credential file; it is not the final signing boundary.
