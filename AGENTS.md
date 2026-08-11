# PROJECT KNOWLEDGE BASE

**Generated:** 2026-08-10
**Commit:** 756a8ae
**Branch:** main

## OVERVIEW

SoltrOS Reborn is an immutable, gaming-oriented Fedora 44 bootc project with four isolated desktop images: KDE Plasma, GNOME, Niri + Dank Material Shell, and Niri + Noctalia. The images share gaming, MacBook, and developer layers but keep display managers, sessions, portals, and desktop defaults in variant-specific build scripts and overlays. A manifest-driven Anaconda LiveISO lets users select one variant during installation.

## STRUCTURE

```text
.
├── build_files/                  # Ordered image build and provisioning scripts
├── disk_config/                  # ISO, disk, and installer configuration
├── repo_files/                   # Package repository definitions and Flatpak refs
├── resources/                    # Installer scripts, signing policy, and branding assets
├── system_files/                 # Files copied into the image filesystem
├── desktop_files/                # Variant-specific system and session overlays
├── variants/                     # Desktop variant manifest used by CI and installers
├── tests/                        # Contract tests for image and installer boundaries
├── .github/workflows/            # CI image build and registry publishing
├── Dockerfile                    # Multi-stage Fedora bootc image definition
├── README.md                     # User-facing project documentation
└── why.md                        # Technical architecture and design rationale
```

## WHERE TO LOOK

| Task | Location | Notes |
| --- | --- | --- |
| Change image stages | `Dockerfile` | Controls base image, copied files, package setup, and final bootc commit. |
| Add build behavior | `build_files/` | Called in order by `build_files/build.sh`; scripts run inside the image build. |
| Change runtime commands | `system_files/usr/share/soltros/bin/` | `helper.sh` is the primary command dispatcher; `nixmanager.sh` manages Nix packages. |
| Change system defaults | `system_files/etc/` | Includes dconf, GRUB, systemd, WirePlumber, repository, and thermal settings. |
| Change installer behavior | `disk_config/iso.toml`, `disk_config/generate-iso-config.sh`, `resources/live-install.sh` | The ISO selector chooses a manifest-backed image; keep prompts and validation in English. |
| Change CI publishing | `.github/workflows/build.yml` | Builds on pull requests and publishes/signs images on `main`. |
| Verify translations | `rg -n -P '[\\x{3400}-\\x{4DBF}\\x{4E00}-\\x{9FFF}\\x{F900}-\\x{FAFF}]' --hidden -g '!.git' .` | The command must return no project-language hits. |

## BUILD AND VALIDATION

The canonical local KDE build is:

```bash
podman build --build-arg DESKTOP_VARIANT=kde -t soltros-os .
```

The other variants use the `base_image` and `id` values in `variants/desktop-variants.json`. Build the LiveISO only after the selected carrier image is available to rootful Podman:

```bash
disk_config/build-live-iso.sh output/liveiso
```

When Podman is unavailable, validate shell syntax without executing privileged image operations:

```bash
find build_files system_files -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n
```

Review a generated image with `podman run --rm -it soltros-os` when a local image build is available. CI builds the full manifest matrix and then publishes a desktop-selectable Anaconda ISO from the KDE carrier image.

## IMPLEMENTATION CONVENTIONS

- Preserve the build order in `build_files/build.sh`; add a new stage there only when its ordering dependency is explicit.
- Keep image changes declarative in `Dockerfile`, `system_files/`, `repo_files/`, or the smallest focused build script.
- Use `set -euo pipefail` (or the existing equivalent) in shell scripts and quote variable expansions at command boundaries.
- Do not commit credentials, private keys, registry tokens, cookies, or personal data. The repository may contain the public signing key `soltros.pub`.
- Preserve existing user changes and avoid unrelated formatting or history rewrites.

## LANGUAGE AND COMMITS

- All repository content must be written in English, except files that are explicitly maintained as translations.
- New or modified comments, user-facing messages, documentation, configuration descriptions, and examples must be English.
- Every commit title and commit body must be written in English, including commits whose code change is a translation.
- Do not add Chinese text to source files, scripts, documentation, configuration, commit metadata, or review artifacts.

## DELIVERY CHECKLIST

Before submitting changes:

1. Run the Chinese-character scan and confirm it has no matches.
2. Run `git diff --check`.
3. Run shell syntax checks for changed scripts and the most relevant build/test command.
4. Report build or runtime checks that could not run because required container tooling or network dependencies were unavailable.
