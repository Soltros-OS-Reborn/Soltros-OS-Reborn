# LiveISO Distribution Research

Date: 2026-08-29

## Current Constraints

SoltrOS builds one desktop-selectable Fedora 44 LiveISO containing four
embedded bootc variants. The current GitHub Actions workflow stores the ISO as a
temporary artifact and the release workflow attempts to attach it to a GitHub
Release. The build rootfs is already about 28 GiB before final compression, so
the final ISO must be treated as a multi-gigabyte distribution artifact rather
than a repository file.

## Platform Findings

| Platform | Relevant limit/cost | Strength | Decision |
| --- | --- | --- | --- |
| GitHub Releases | Each asset must be under 2 GiB; up to 1000 assets; no total-release or bandwidth limit | Excellent release notes, API, immutable releases, checksums and signatures | Metadata and small artifacts only; not the primary ISO host unless the ISO is proven below 2 GiB |
| GitHub Actions artifacts | Temporary CI hand-off with plan-dependent storage and retention limits | Convenient between build and publish jobs | Never the public download surface; retain only long enough to publish |
| Cloudflare R2 | Standard storage $0.015/GB-month, 10 GB-month free tier, Internet egress free; object limit 5 TiB; multipart uploads supported | Low predictable cost, S3 API, custom domain, HTTP delivery, range-friendly object downloads | Recommended primary host with a custom domain |
| Cloudflare `r2.dev` | Managed public URL is for development/testing and is rate- and throughput-limited | Zero setup for a smoke test | Do not use as the production download URL |
| SourceForge FRS | Free managed global mirror network and download statistics; mirrors can be rotated and may not carry every file | Good fit for public open-source ISO distribution and regional mirrors | Recommended free secondary mirror after the first stable release |
| Backblaze B2 | First 10 GB free; egress free up to 3x average monthly stored data, then $0.01/GB; S3-compatible | Cheap fallback and easy migration | Viable alternative if R2/custom-domain setup is unavailable; less predictable for viral downloads |
| Internet Archive | Large-file archival workflow; upload guidance recommends keeping an item below roughly 500 GB | Long-term preservation and independent backup | Optional archival mirror, not the canonical fast download surface |
| Codeberg | 750 MiB Git storage plus 1.5 GiB for packages/LFS/attachments by default | Good FOSS forge | Unsuitable for this LiveISO size |
| GitLab package registry | Public package support, rate limits, storage/cleanup policies vary by tier | Useful for package ecosystems | Not cost-efficient or operationally simple for a multi-gigabyte ISO |

## Cost Model

Using the current R2 standard rate, a 16 GiB ISO costs approximately $0.09 per
month after the 10 GB-month free allowance. A 28 GiB object costs approximately
$0.27 per month after the same allowance. Downloads do not incur R2 Internet
egress charges. Request charges are negligible for normal release downloads but
must still be monitored if a URL is abused.

The estimate excludes the domain because a project domain can be reused for the
download hostname. R2's `r2.dev` URL should not be used for production because
Cloudflare applies variable request and throughput throttling to it. A custom
domain also enables cache rules, WAF controls, redirects, and analytics. On
Cloudflare Free/Pro/Business plans, files above the documented 512 MiB cacheable
size are not cached at the edge; the download still works from R2, but a mirror
or peer distribution path is valuable for high traffic.

## Recommended Topology

### Primary: Cloudflare R2

Use one private bucket with a production custom domain such as
`download.soltros.dev` (the actual hostname is a deployment decision). Publish
objects under immutable versioned paths:

```text
releases/1.0.0/SoltrOS-live-1.0.0-live-x86_64.iso
releases/1.0.0/SoltrOS-live-1.0.0-live-x86_64.iso.sha256
releases/1.0.0/SoltrOS-live-1.0.0-live-x86_64.iso.sigstore.json
releases/1.0.0/release-index.json
releases/1.0.0/embedded-image-inventory.json
```

Use a small mutable pointer such as `stable.json` only as a convenience. The
installer and release notes must always expose the immutable versioned URL and
SHA-256. Set `Content-Type: application/octet-stream`, long immutable caching
for versioned files, and verify HTTP range requests before announcing a release.

### Public mirror: SourceForge

Mirror each stable ISO and its checksum/signature bundle through SourceForge's
File Release System. Its geographically distributed mirrors are useful for
large public downloads and its statistics can reveal demand without adding
another paid egress bill. Keep R2 as the canonical checksum source and compare
the mirror file hash after every upload.

### Release metadata: GitHub

Keep the GitHub Release as the human-facing release record. Attach the checksum,
Sigstore bundle, SPDX SBOM, provenance, inventory, release index, and a small
`download.html` or Markdown section linking to R2 and SourceForge. Do not attach
the ISO when it exceeds 2 GiB. Enable immutable releases, create a draft, attach
all small artifacts, verify hashes and signatures, then publish.

### Optional archival copy: Internet Archive

After a stable release is verified, upload a copy for preservation. Mark it as
an archival mirror and keep the R2 URL canonical. Do not make installers depend
on the archive's indexing or derivation latency.

## Release Pipeline to Borrow

1. Build the ISO once in CI and generate SHA-256, Sigstore, SPDX, provenance,
   embedded-image inventory, and a machine-readable release index.
2. Upload the ISO to a temporary versioned R2 key with multipart upload.
3. Download it back through the public custom domain using a range request and
   verify the complete SHA-256 before publishing any pointer.
4. Upload the same bytes to SourceForge, then verify its checksum independently.
5. Create a GitHub draft release containing only metadata and small artifacts.
6. Publish the immutable GitHub release and update `stable.json` only after both
   download endpoints pass verification.
7. Retain the previous stable object and pointer until the new release has
   passed installation QA. Delete only superseded temporary CI artifacts.

## Integrity and Abuse Controls

- The ISO's SHA-256 must be identical across CI, R2, SourceForge, and the
  published release index.
- Keep Sigstore verification in the release workflow and show the verification
  command in the release notes.
- Never overwrite a versioned R2 key. A corrected build receives a new version
  or build identifier.
- Add R2 usage alerts and a maximum monthly budget. Keep the bucket private until
  the custom domain, cache, WAF, and download monitoring are configured.
- Prefer resumable HTTP downloads and optionally publish a `.torrent` or
  `zsync` sidecar after the direct path is proven. Peer distribution is a
  bandwidth optimization, not an integrity replacement.

## Rejected Approaches

- Git LFS: its quota and bandwidth billing are intended for source assets, not a
  public operating-system ISO.
- GitHub Actions artifacts: temporary retention and plan quotas make them an
  unreliable public mirror.
- Codeberg Releases: the default attachment/package quota is below the ISO size.
- A self-hosted VPS as the first release host: it adds patching, storage, backup,
  and egress risk before download demand is known.
- Splitting the ISO into many GitHub assets: it complicates user downloads and
  installer documentation without reducing the underlying storage/egress cost.

## Recommended First Release

Start with R2 as the canonical host and GitHub Release as the signed index. Add
SourceForge when the first stable ISO has passed installation QA. Add Internet
Archive only after the canonical path and mirror checks are automated. This keeps
the initial recurring cost close to the R2 storage charge while retaining a free
mirror path for larger public demand.

## Sources

- GitHub Releases: <https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases>
- GitHub immutable releases: <https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases>
- Cloudflare R2 pricing: <https://developers.cloudflare.com/r2/pricing>
- Cloudflare R2 limits and `r2.dev` restrictions: <https://developers.cloudflare.com/r2/platform/limits>
- Cloudflare R2 public buckets and custom domains: <https://developers.cloudflare.com/r2/buckets/public-buckets>
- Cloudflare R2 cache behavior: <https://developers.cloudflare.com/cache/interaction-cloudflare-products/r2>
- SourceForge mirrors: <https://sourceforge.net/p/forge/documentation/Mirrors>
- SourceForge project features: <https://sourceforge.net/create>
- Backblaze B2 pricing: <https://www.backblaze.com/cloud-storage/pricing>
- Internet Archive upload limits: <https://help.archive.org/help/uploading-troubleshooting>
- Codeberg storage quotas: <https://docs.codeberg.org/getting-started/faq>
- GitLab package registry cleanup: <https://docs.gitlab.com/user/packages/package_registry/reduce_package_registry_storage>
