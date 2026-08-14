# Release and Rollback Procedure

## Publication Gate

Reborn publication is enabled for the public `ghcr.io/soltros-os-reborn`
namespace. Both publication flags in `release/release.json` must remain true for
a main-branch build to publish. Organization administrators must allow public
package creation and set each official package to public before its first
release. The build workflow creates and updates each package with the
repository-scoped `packages: write` token, then verifies an anonymous OCI pull
only after signing, attestation verification, and `dev` channel promotion
complete. This keeps package-administration credentials out of Actions.

The repository uses a Reborn-owned Cosign key. Its public-key SHA-256
fingerprint is:

```text
e1c573c15443f249a0603c83d71658737ab00e2d2c8e7c667f378f7972ad557b
```

`COSIGN_PRIVATE_KEY` and `COSIGN_PASSWORD` are repository Actions secrets. The
encrypted private key must never be committed. After a future key rotation,
replace `soltros.pub`, update `trust.public_key_sha256`, refresh both secrets,
run `just generate-release-assets`, and publish a complete four-image set.

## Image Build

The build workflow validates source contracts and builds all four manifest
variants. Every image is inspected, smoke-tested with `bootc container lint`,
and assigned only the immutable `sha-<full-commit>` tag before publication. The
workflow generates SPDX and SLSA provenance, pushes the immutable image, signs
and verifies its digest, attaches and verifies both attestations, and finally
copies that digest to the `dev` channel.

No pull-request build publishes images. Official public package endpoints are:

- `ghcr.io/soltros-os-reborn/soltros-os`;
- `ghcr.io/soltros-os-reborn/soltros-os-gnome`;
- `ghcr.io/soltros-os-reborn/soltros-os-niri-dms`;
- `ghcr.io/soltros-os-reborn/soltros-os-niri-noctalia`.

## Channel Promotion

Run **Promote SoltrOS Reborn channel** manually. The workflow accepts only these
manifest-generated transitions:

1. `dev` to `testing`;
2. `testing` to `stable`;
3. `stable` to `latest`.

For each desktop image it resolves and verifies the signed source digest, copies
that exact digest to the target channel, signs it, compares the resulting target
digest, and verifies the target signature. Skipping a channel is rejected by the
generated policy.

## LiveISO Release

After a successful gated build containing the LiveISO, run **Publish SoltrOS
Reborn release** with its workflow run ID and the desired release tag. The
workflow requires a successful source run, downloads its artifacts, verifies all
checksums, signs and verifies every ISO with a Sigstore bundle, and creates a
durable GitHub Release containing the ISO, checksum, signature bundle, SPDX SBOM,
provenance, embedded-image inventory,
release index, and per-image metadata.

## Rollback

Channel rollback never rebuilds an image. Identify the previously approved
`sha-<full-commit>` digest, verify its Cosign signature and attestations, then run
the promotion workflow from the preceding signed channel after restoring that
channel to the approved digest. Installed systems can select their previous
deployment with `soltros rollback` and reboot. Keep the bad immutable tag for
audit purposes; move only mutable channels.

If a publication workflow stops before promotion, the immutable digest remains
unreferenced by a release channel and is safe to retain. If it stops after one
variant is promoted, restore the previous signed digest for that variant before
rerunning the complete matrix so all four channels represent one release set.
