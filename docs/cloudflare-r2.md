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
- Reserved private bucket: `packages-signing`, WNAM, Standard storage class.
- Custom domain: `hypxr.omedora.org`, minimum TLS 1.2.
- Development `r2.dev` public URL: disabled.
- Unused Secrets Store: `hypxr`, empty.
- Cache rule: repository databases and signatures bypass cache.
- Cache rule: versioned package archives and signatures cache for one year;
  4xx and 5xx responses have a zero-second cache TTL.

GitHub Actions uses separate R2 Object Read & Write Account API tokens for the
private staging bucket and public repository bucket. Wrangler OAuth does not
authenticate rclone, and Secrets Store values cannot be read by GitHub Actions.
Repository clients use the public custom hostname and need no token.

Create each token in **Storage & databases → R2 → Overview → Manage API
Tokens**. Choose **Object Read & Write** and scope it to exactly one bucket.
The staging pair belongs in the `staging` GitHub environment; the `packages`
pair belongs only in the reviewer-protected `production` environment. Do not
paste either value into Git, chat, or a shell argument. The workflow configures
rclone from masked environment values. A recovery host can use:

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

Ordinary CI receives write access only to `packages-staging`. The manually
approved production job receives a separate token for `packages`, verifies and
signs every artifact, then publishes packages first and mutable repository
metadata last. `packages-signing` and Secrets Store remain unused after the
decision not to require a paid Cloudflare Container signer. See
[`github-actions.md`](github-actions.md).

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
