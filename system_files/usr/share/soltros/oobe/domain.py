from __future__ import annotations

import json
import os
from dataclasses import dataclass
from datetime import UTC, datetime
from email.headerregistry import Address
from enum import StrEnum, unique
from pathlib import Path
from typing import Final, assert_never

STATE_SCHEMA_VERSION: Final = 1
SETTLED_OUTCOMES: Final = frozenset({"completed", "deferred"})


class SelectionError(ValueError):
    pass


class CompletionOutcomeError(ValueError):
    def __init__(self, outcome: str) -> None:
        self.outcome = outcome
        super().__init__(f"Unsupported setup outcome: {outcome}")


@unique
class ShellChoice(StrEnum):
    KEEP = "keep"
    BASH = "bash"
    FISH = "fish"
    ZSH = "zsh"


@dataclass(frozen=True, slots=True)
class SetupSelection:
    git_name: str = ""
    git_email: str = ""
    shell: ShellChoice = ShellChoice.KEEP
    setup_cli: bool = False
    recommended_apps: bool = False
    gaming_apps: bool = False
    development_apps: bool = False
    multimedia_apps: bool = False


@dataclass(frozen=True, slots=True)
class TaskSpec:
    task_id: str
    label: str
    commands: tuple[tuple[str, ...], ...]
    requires_network: bool = False
    may_authenticate: bool = False


@dataclass(frozen=True, slots=True)
class SystemProfile:
    variant_id: str
    variant_name: str


def _normalized_git_identity(selection: SetupSelection) -> tuple[str, str] | None:
    name = selection.git_name.strip()
    email = selection.git_email.strip()
    if not name and not email:
        return None
    if not name or not email:
        raise SelectionError("Enter both a Git name and email, or leave both empty.")
    try:
        address = Address(addr_spec=email)
    except ValueError as error:
        raise SelectionError("Enter a valid Git email address.") from error
    if not address.username or not address.domain:
        raise SelectionError("Enter a valid Git email address.")
    return name, address.addr_spec


def _shell_path(shell: ShellChoice) -> str | None:
    match shell:
        case ShellChoice.KEEP:
            return None
        case ShellChoice.BASH:
            return "/usr/bin/bash"
        case ShellChoice.FISH:
            return "/usr/bin/fish"
        case ShellChoice.ZSH:
            return "/usr/bin/zsh"
        case _ as unreachable:
            assert_never(unreachable)


def build_tasks(selection: SetupSelection, username: str) -> tuple[TaskSpec, ...]:
    tasks: list[TaskSpec] = []
    identity = _normalized_git_identity(selection)
    if identity is not None:
        name, email = identity
        tasks.append(
            TaskSpec(
                task_id="git-identity",
                label="Configure Git identity",
                commands=(
                    ("/usr/bin/git", "config", "--global", "user.name", name),
                    ("/usr/bin/git", "config", "--global", "user.email", email),
                ),
            )
        )

    shell_path = _shell_path(selection.shell)
    if shell_path is not None:
        tasks.append(
            TaskSpec(
                task_id="default-shell",
                label=f"Set {selection.shell.value} as the default shell",
                commands=((
                    "/usr/bin/pkexec",
                    "/usr/sbin/usermod",
                    "--shell",
                    shell_path,
                    username,
                ),),
                may_authenticate=True,
            )
        )

    if selection.setup_cli:
        tasks.append(
            TaskSpec(
                task_id="shell-integrations",
                label="Install verified shell integrations",
                commands=(("/usr/bin/soltros", "setup-cli"),),
                requires_network=True,
            )
        )

    software_profiles = (
        (
            selection.recommended_apps,
            "recommended-apps",
            "Install recommended applications",
            "install-flatpaks",
        ),
        (
            selection.gaming_apps,
            "gaming-apps",
            "Install gaming applications",
            "install-gaming",
        ),
        (
            selection.development_apps,
            "development-apps",
            "Install development applications",
            "install-dev-tools",
        ),
        (
            selection.multimedia_apps,
            "multimedia-apps",
            "Install multimedia applications",
            "install-multimedia",
        ),
    )
    for selected, task_id, label, command in software_profiles:
        if selected:
            tasks.append(
                TaskSpec(
                    task_id=task_id,
                    label=label,
                    commands=(("/usr/bin/soltros", command),),
                    requires_network=True,
                    may_authenticate=True,
                )
            )
    return tuple(tasks)


def default_state_file() -> Path:
    state_home = os.environ.get("XDG_STATE_HOME")
    if state_home:
        return Path(state_home) / "soltros" / "oobe" / "completion.json"
    return Path.home() / ".local" / "state" / "soltros" / "oobe" / "completion.json"


def is_setup_settled(state_file: Path) -> bool:
    try:
        state = json.loads(state_file.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return False
    return (
        state.get("schema_version") == STATE_SCHEMA_VERSION
        and state.get("outcome") in SETTLED_OUTCOMES
    )


def automatic_setup_required(root: Path, state_file: Path) -> bool:
    if (root / ".liveimg").exists() or is_setup_settled(state_file):
        return False
    metadata_file = root / "var" / "lib" / "soltros" / "installation.json"
    try:
        metadata = json.loads(metadata_file.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        return False
    return metadata.get("oobe_required") is True


def write_completion(state_file: Path, outcome: str, task_ids: list[str]) -> None:
    if outcome not in SETTLED_OUTCOMES:
        raise CompletionOutcomeError(outcome)
    payload = {
        "schema_version": STATE_SCHEMA_VERSION,
        "outcome": outcome,
        "completed_at": datetime.now(UTC).isoformat(),
        "task_ids": task_ids,
    }
    state_file.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    temporary = state_file.with_suffix(".tmp")
    temporary.write_text(
        json.dumps(payload, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    temporary.chmod(0o600)
    temporary.replace(state_file)


def load_system_profile(root: Path) -> SystemProfile:
    variant_file = root / "usr" / "lib" / "soltros" / "desktop-variant"
    manifest_file = root / "usr" / "share" / "soltros" / "desktop-variants.json"
    try:
        variant_id = variant_file.read_text(encoding="utf-8").strip()
        variants = json.loads(manifest_file.read_text(encoding="utf-8"))
        variant_name = next(
            entry["display_name"]
            for entry in variants
            if entry.get("id") == variant_id
        )
    except (FileNotFoundError, json.JSONDecodeError, OSError, StopIteration, KeyError):
        return SystemProfile(variant_id="unknown", variant_name="SoltrOS Reborn")
    return SystemProfile(variant_id=variant_id, variant_name=str(variant_name))
