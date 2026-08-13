# Cloudflare R2 publication setup

The recommended origin is a private Cloudflare R2 Standard bucket named
`packages`, exposed through a long-lived custom hostname such as
`packages.hypxr.dev`. The repository layout remains:

```text
/edge/x86_64/
/stable/x86_64/
```

R2 fits the existing `hypxr:packages` rclone destination, provides S3 API and
Range request support, and avoids egress charges. Do not use the development
`r2.dev` hostname for production clients.

## Provisioning

1. Put the chosen long-lived domain in Cloudflare DNS.
2. Create an R2 Standard bucket named `packages`.
3. Create an R2 API token restricted to Object Read & Write for only that
   bucket. Repository clients use the public custom hostname and do not need
   this token.
4. Attach the production custom domain to the bucket and disable its `r2.dev`
   public URL.
5. Configure the publication host's rclone remote:

   ```ini
   [hypxr]
   type = s3
   provider = Cloudflare
   access_key_id = REDACTED
   secret_access_key = REDACTED
   endpoint = https://ACCOUNT_ID.r2.cloudflarestorage.com
   region = auto
   no_check_bucket = true
   acl = private
   ```

6. Add a Cloudflare Cache Rule that bypasses cache for every path matching
   `*/hypxr.db*` or `*/hypxr.files*`, including detached signatures.
7. Cache immutable `*.pkg.tar.zst` and `*.pkg.tar.zst.sig` objects for one year.
   Set cached 404 TTL to zero.

The sync code also assigns these origin metadata policies:

- Packages and package signatures: `public, max-age=31536000, immutable,
  no-transform`.
- Repository databases and database signatures: `no-store, max-age=0,
  must-revalidate, no-transform`.

The explicit Cloudflare bypass remains required for mutable metadata. R2 is
strongly consistent at the bucket API, but caching overwritten custom-domain
objects can otherwise expose different database and signature generations.

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
