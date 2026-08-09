# PROJECT KNOWLEDGE BASE

**Generated:** 2026-08-10
**Commit:** 756a8ae
**Branch:** main

## OVERVIEW

SoltrOS Reborn is an immutable, gaming-oriented Fedora Kinoite/bootc image with KDE Plasma, MacBook support, the CachyOS kernel, and developer tooling. The image is assembled by `Dockerfile`, which copies static files from `system_files/` and runs the ordered build stages in `build_files/`.

## STRUCTURE

```text
.
├── build_files/                  # Ordered image build and provisioning scripts
├── disk_config/                  # ISO, disk, and installer configuration
├── repo_files/                   # Package repository definitions and Flatpak refs
├── resources/                    # Installer scripts, signing policy, and branding assets
├── system_files/                 # Files copied into the image filesystem
├── .github/workflows/            # CI image build and registry publishing
├── Dockerfile                    # Multi-stage Fedora Kinoite image definition
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
| Change installer behavior | `resources/live-install.sh` | Live installation flow; keep prompts and validation in English. |
| Change CI publishing | `.github/workflows/build.yml` | Builds on pull requests and publishes/signs images on `main`. |
| Verify translations | `rg -n -P '[\\x{3400}-\\x{4DBF}\\x{4E00}-\\x{9FFF}\\x{F900}-\\x{FAFF}]' --hidden -g '!.git' .` | The command must return no project-language hits. |

## BUILD AND VALIDATION

The canonical local build is:

```bash
podman build -t soltros-os .
```

When Podman is unavailable, validate shell syntax without executing privileged image operations:

```bash
find build_files system_files -type f -name '*.sh' -print0 | xargs -0 -n1 bash -n
```

Review the generated image with `podman run --rm -it soltros-os` when a local image build is available. CI uses the pinned GitHub Actions workflow in `.github/workflows/build.yml`.

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
