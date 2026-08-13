# Cloudflare R2 publication setup

The live origin is a private Cloudflare R2 Standard bucket named `packages`,
exposed through `hypxr.omedora.org`. The repository layout is:

```text
/edge/x86_64/
/stable/x86_64/
```

R2 fits the existing `hypxr:packages` rclone destination, provides S3 API and
Range request support, and avoids egress charges. Do not use the development
`r2.dev` hostname for production clients.

## Provisioned resources

The non-secret resource identifiers are tracked in
[`../infrastructure/cloudflare.json`](../infrastructure/cloudflare.json).

- Published bucket: `packages`, WNAM, Standard storage class.
- Private upload bucket: `packages-staging`, WNAM, Standard storage class.
- Private frozen-input bucket: `packages-signing`, WNAM, Standard storage
  class.
- Custom domain: `hypxr.omedora.org`, minimum TLS 1.2.
- Development `r2.dev` public URL: disabled.
- Secrets Store: `hypxr`.
- Cache rule: repository databases and signatures bypass cache.
- Cache rule: versioned package archives and signatures cache for one year;
  4xx and 5xx responses have a zero-second cache TTL.

The temporary external publisher needs a bucket-scoped R2 Object Read & Write
Account API token restricted to `packages`. Wrangler OAuth does not authenticate
rclone, and Secrets Store values cannot be read by an external process.
Repository clients use the public custom hostname and need no token.

Create the token in **Storage & databases → R2 → Overview → Manage API
Tokens**. Choose **Object Read & Write**, apply it only to `packages`, and put
the Access Key ID and Secret Access Key into the publisher's root-owned `0600`
credential file as `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`. Do not paste
either value into Git, chat, or a shell argument. Configure rclone without
secret values:

   ```ini
   [hypxr]
   type = s3
   provider = Cloudflare
   env_auth = true
   endpoint = https://b56864690db4b781dbf36b94155d808c.r2.cloudflarestorage.com
   region = auto
   no_check_bucket = true
   acl = private
   ```

The sync code also assigns these origin metadata policies:

- Packages and package signatures: `public, max-age=31536000, immutable,
  no-transform`.
- Repository databases and database signatures: `no-store, max-age=0,
  must-revalidate, no-transform`.

The explicit Cloudflare bypass is installed for mutable metadata. R2 is
strongly consistent at the bucket API, but caching overwritten custom-domain
objects could otherwise expose different database and signature generations.

The target signer uses direct R2 bindings instead of an S3 token. CI receives
write access only to `packages-staging`; the signer alone can freeze verified
objects into `packages-signing` and publish to `packages`. See
[`cloudflare-signer.md`](cloudflare-signer.md).

## Publication check

Before adding the installer URL to public documentation:

1. Publish the signed keyring and complete package wave to edge.
2. Confirm HTTPS `HEAD`, full `GET`, and Range `GET` against a package.
3. Confirm metadata responses are uncached and carry the expected
   `Cache-Control` value.
4. Verify `hypxr.db.sig` and `hypxr.files.sig` with the checked-in public key.
5. Run the generated bootstrap in a clean vanilla Omarchy machine.
6. Install `hypxrland-omarchy`, test XR hardware, log out, and prove the stock
   Omarchy session still starts.
7. Promote the exact tested artifacts to stable only after its Hyprland ABI is
   compatible.

Publication uploads immutable packages first, database signatures second, and
databases last. A client in the short metadata transition fails closed. Never
cache the database and its signature independently.
