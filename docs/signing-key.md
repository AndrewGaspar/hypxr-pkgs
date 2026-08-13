# HypXR signing-key ceremony and retention

The repository trust root is an offline, certification-only OpenPGP primary
key. Package and database releases use a separate, expiring signing subkey.
The protected production environment must never receive an export containing
the usable primary secret key.

## Custody model

- Keep two encrypted backups of the complete primary secret key on separate
  offline media in separate physical locations.
- Keep the revocation certificate with both backups.
- Keep a recovery signing subkey offline but include its public half in the
  published keyring. It can sign a keyring update if the active publisher key
  is lost or compromised.
- Put only the active operational signing subkey in the protected production
  GitHub environment.
- Give operational signing subkeys a one-year expiry and rotate with 60–90
  days of overlap.
- Test both offline backups after creation and annually.

LastPass is reasonable for the operational subkey passphrase if the account
has a unique high-entropy master password and hardware MFA. Do not store the
only primary-key backup there, and do not store the primary-key export and its
passphrase together in the same vault item. Offline media remain the recovery
source of truth.

## Offline ceremony

Perform this on an offline machine or a temporary offline live system. Use a
new empty `GNUPGHOME` on encrypted storage and replace the example identity
with the final repository identity:

```bash
export GNUPGHOME=/secure/offline/hypxr-gnupg
install -d -m 0700 "$GNUPGHOME"

gpg --quick-generate-key \
  'HypXR Package Repository <packages@omedora.org>' \
  ed25519 cert 5y

PRIMARY_FINGERPRINT=$(gpg --with-colons --list-secret-keys |
  awk -F: '$1 == "fpr" { print $10; exit }')

gpg --quick-add-key "$PRIMARY_FINGERPRINT" ed25519 sign 1y
gpg --quick-add-key "$PRIMARY_FINGERPRINT" ed25519 sign 5y
```

The first signing subkey is operational. The second is recovery-only. Record
both full subkey fingerprints:

```bash
gpg --with-colons --with-subkey-fingerprint \
  --list-secret-keys "$PRIMARY_FINGERPRINT"
```

Export the public certificate, the complete offline backup, the revocation
certificate, and an operational-subkeys-only transfer:

```bash
gpg --armor --export "$PRIMARY_FINGERPRINT" >hypxr-public.asc
gpg --armor --export-secret-keys "$PRIMARY_FINGERPRINT" >hypxr-primary-backup.asc
gpg --output hypxr-revocation.asc --gen-revoke "$PRIMARY_FINGERPRINT"
OPERATIONAL_SIGNING_FINGERPRINT=REPLACE_WITH_FIRST_SIGNING_SUBKEY_FINGERPRINT
gpg --armor --export-secret-subkeys "$OPERATIONAL_SIGNING_FINGERPRINT!" \
  >hypxr-publisher-subkey.asc
```

The exclamation point makes the transfer export select exactly the operational
subkey. Verify it on a disposable machine before placing it on the publisher:
its primary secret key should be a `sec#` stub, the operational signing subkey
should be usable, and the recovery subkey should have no secret material.

The production environment uses:

```bash
export GPG_PRIVATE_KEY='armored operational subkey export only'
export GPG_PASSPHRASE='operational subkey passphrase'
export HYPXR_PUBLIC_KEY='armored public certificate'
export HYPXR_PRIMARY_FINGERPRINT='40_HEX_PRIMARY_FINGERPRINT'
export HYPXR_SIGNING_SUBKEY_FINGERPRINT='40_HEX_OPERATIONAL_SUBKEY_FINGERPRINT'
```

The production secret names are `HYPXR_GPG_PRIVATE_KEY` and
`HYPXR_GPG_PASSPHRASE` in the `hypxr` Cloudflare Secrets Store. The store is
only a binding source for the planned Cloudflare signer; it cannot be read by
the temporary external publication host. Do not populate either value until
the signer has been reviewed and deployed with a disposable test key. Measure
the armored operational export first: each Secrets Store value is limited to
1,024 bytes. Never substitute an export containing the primary or recovery
secret key.

Generate the keyring package and edge installer only after independently
checking the recorded primary fingerprint:

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

Review and commit the generated public files. Never commit either secret-key
export or a passphrase.

## Rotation

Routine signing-subkey rotation keeps the same primary fingerprint. Publish
the new public subkey in `hypxr-keyring` while the old signing key still works,
upgrade clients, then switch the publisher and eventually revoke or expire the
old subkey. A primary-key rotation requires a staged keyring update signed by
the old trust root; losing the primary without an offline backup cannot be
recovered transparently.
