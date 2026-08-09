# SOLTROS RUNTIME TOOLS

This directory contains files installed under `/usr/share/soltros` in the image. `bin/helper.sh` is the main command-line entry point, `bin/nixmanager.sh` integrates Nix packages with desktop caches, and `bling/` contains shell defaults, aliases, and plugins.

## Rules

- Keep command names and their documented help output stable unless the user-facing interface is intentionally changed.
- Preserve `set -euo pipefail` and check external commands before invoking optional integrations.
- Runtime messages, help text, and comments must be English.
- Do not write credentials or machine-specific personal data to generated files.

## Validation

Run `bash -n system_files/usr/share/soltros/bin/*.sh` and inspect the affected command with a disposable environment. Full runtime validation requires the built image and a booted SoltrOS system.
