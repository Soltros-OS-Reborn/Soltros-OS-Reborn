# BUILD SCRIPTS

`build.sh` is the ordered entry point invoked by the `Dockerfile`. It executes signing, Nix, Waterfox, KDE, desktop packages, desktop defaults, gaming, overrides, initramfs generation, and cleanup stages.

## Rules

- Keep each stage idempotent where practical and fail fast with the local `set -euo pipefail` convention.
- Preserve the order in `build.sh`; later scripts may rely on files or packages created by earlier stages.
- Use `log` or `echo_group` for build output so CI logs remain searchable.
- Build scripts run as root inside the image. Never hard-code secrets or host paths.
- Keep all comments and emitted user-facing text in English.

## Validation

Run `bash -n build_files/*.sh` for syntax validation. A full `podman build -t soltros-os .` is the behavioral check when Podman and network access are available.
