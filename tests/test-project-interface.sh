#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
justfile="${repo_root}/Justfile"
roadmap="${repo_root}/docs/architecture-roadmap.md"
build_workflow="${repo_root}/.github/workflows/build.yml"

for recipe in test validate build-image build-images build-offline-payload build-liveiso run-liveiso; do
    just --justfile "${justfile}" --summary | tr ' ' '\n' | grep -Fxq "${recipe}" || {
        printf 'project task interface is missing recipe: %s\n' "${recipe}" >&2
        exit 1
    }
done

grep -Fq 'Reborn image has been published' "${roadmap}"
grep -Fq 'complete, usable offline SoltrOS environment' "${roadmap}"
grep -Fq 'user explicitly opts in' "${roadmap}"

if ! grep -Eq 'apt-get install --yes .*\bripgrep\b' "${build_workflow}"; then
    echo 'validation job must install ripgrep before running rg-based contracts' >&2
    exit 1
fi

printf 'PASS: project task interface and architecture ledger contracts\n'
