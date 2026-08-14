# Release and Rollback Procedure

## Publication Gate

Reborn publication is disabled while either `publication.enabled` or
`publication.repository_ready` is `false` in `release/release.json`. Enabling a
release requires the GHCR namespace, package permissions, Cosign private key,
password, and public key to be configured first. Regenerate and commit release
assets with `just generate-release-assets` after changing the manifest.

## Image Build

The build workflow validates source contracts and builds all four manifest
variants. Every image is inspected, smoke-tested with `bootc container lint`,
and assigned only the immutable `sha-<full-commit>` tag before publication. The
workflow generates SPDX and SLSA provenance, pushes the immutable image, signs
and verifies its digest, attaches and verifies both attestations, and finally
copies that digest to the `dev` channel.

No pull-request build publishes images. A main-branch build also remains local
while the publication gate is closed.

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
checksums, signs every ISO, and creates a durable GitHub Release containing the
ISO, checksum, signature, SPDX SBOM, provenance, embedded-image inventory,
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
