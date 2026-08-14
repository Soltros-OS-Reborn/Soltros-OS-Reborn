#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
justfile="${repo_root}/Justfile"
roadmap="${repo_root}/docs/architecture-roadmap.md"

for recipe in test validate build-image build-images build-offline-payload build-liveiso run-liveiso; do
    just --justfile "${justfile}" --summary | tr ' ' '\n' | grep -Fxq "${recipe}" || {
        printf 'project task interface is missing recipe: %s\n' "${recipe}" >&2
        exit 1
    }
done

grep -Fq 'Reborn image has been published' "${roadmap}"
grep -Fq 'complete, usable offline SoltrOS environment' "${roadmap}"
grep -Fq 'user explicitly opts in' "${roadmap}"

printf 'PASS: project task interface and architecture ledger contracts\n'
