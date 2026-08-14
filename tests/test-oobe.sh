#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
oobe_root="${repo_root}/system_files/usr/share/soltros/oobe"
test_root="$(mktemp -d /tmp/soltros-oobe-XXXXXX)"
trap 'rm -rf "${test_root}"' EXIT

for required_file in __init__.py domain.py executor.py navigation.py pages.py selection.py shortcuts.py views.py window.py main.py; do
  if [[ ! -f "${oobe_root}/${required_file}" ]]; then
    printf 'Missing native OOBE module: %s\n' "${required_file}" >&2
    exit 1
  fi
done

test -x "${repo_root}/system_files/usr/bin/soltros-welcome"
grep -Fq 'OnlyShowIn=GNOME;KDE;' \
  "${repo_root}/system_files/etc/xdg/autostart/org.soltros.Welcome.desktop"
grep -Fq 'spawn-at-startup "soltros-welcome" "--automatic"' \
  "${repo_root}/desktop_files/niri-common/etc/skel/.config/niri/config.kdl"
grep -Fxq 'python3-gobject' "${repo_root}/build_files/packages/core.txt"
grep -Fxq 'libadwaita' "${repo_root}/build_files/packages/core.txt"
grep -Fq 'oobe_required: true' "${repo_root}/resources/live-install.sh"
jq -e '.user_defaults.version >= 2' "${repo_root}/release/release.json" >/dev/null

PYTHONPATH="${oobe_root}" python3 - "${test_root}" <<'PY'
from __future__ import annotations

import json
import sys
import threading
from pathlib import Path

from domain import (
    SelectionError,
    SetupSelection,
    ShellChoice,
    TaskSpec,
    build_tasks,
    is_setup_settled,
    write_completion,
)
from executor import EventKind, ExecutionEvent, ExecutorBusyError, TaskExecutor, TaskResult

test_root = Path(sys.argv[1])
state_file = test_root / "state" / "completion.json"
selection = SetupSelection(
    git_name="SoltrOS User",
    git_email="user@example.test",
    shell=ShellChoice.FISH,
    setup_cli=True,
    recommended_apps=True,
    gaming_apps=False,
    development_apps=True,
    multimedia_apps=False,
)
tasks = build_tasks(selection, username="tester")
assert [task.task_id for task in tasks] == [
    "git-identity",
    "default-shell",
    "shell-integrations",
    "recommended-apps",
    "development-apps",
]
assert tasks[1].commands == (
    ("/usr/bin/pkexec", "/usr/sbin/usermod", "--shell", "/usr/bin/fish", "tester"),
)
assert all(command[0] != "/bin/sh" for task in tasks for command in task.commands)
assert tasks[2].requires_network is True
assert tasks[0].requires_network is False

assert build_tasks(SetupSelection(), username="tester") == ()

try:
    build_tasks(
        SetupSelection(git_name="Name only", git_email=""),
        username="tester",
    )
except SelectionError:
    pass
else:
    raise AssertionError("partial Git identity must be rejected")

write_completion(state_file, outcome="completed", task_ids=[task.task_id for task in tasks])
assert is_setup_settled(state_file)
state = json.loads(state_file.read_text(encoding="utf-8"))
assert state["schema_version"] == 1
assert state["outcome"] == "completed"
assert "git_name" not in state and "git_email" not in state

release_file = test_root / "release"
failure_command = test_root / "fail-task"
failure_command.write_text(
    "#!/usr/bin/env bash\n"
    "set -euo pipefail\n"
    "while [[ ! -f \"$1\" ]]; do sleep 0.01; done\n"
    "printf '\\033[31mexpected failure\\033[0m\\n'\n"
    "exit 7\n",
    encoding="utf-8",
)
failure_command.chmod(0o700)
success_command = test_root / "success-task"
success_command.write_text(
    "#!/usr/bin/env bash\n"
    "printf 'continued after failure\\n'\n",
    encoding="utf-8",
)
success_command.chmod(0o700)
executor = TaskExecutor()
events: list[ExecutionEvent] = []
completed: list[tuple[TaskResult, ...]] = []
done = threading.Event()


def on_complete(results: tuple[TaskResult, ...]) -> None:
    completed.append(results)
    done.set()


executor.start(
    (
        TaskSpec("expected-failure", "Expected failure", ((str(failure_command), str(release_file)),)),
        TaskSpec("continued", "Continued task", ((str(success_command),),)),
    ),
    events.append,
    on_complete,
)
try:
    executor.start((), events.append, on_complete)
except ExecutorBusyError:
    pass
else:
    raise AssertionError("starting a second executor run must fail")
release_file.touch()
assert done.wait(timeout=5), "executor did not finish"
assert [result.success for result in completed[0]] == [False, True]
assert any(event.kind is EventKind.OUTPUT for event in events)
assert all("\x1b" not in event.message for event in events)
assert not executor.running
PY

fake_root="${test_root}/root"
state_home="${test_root}/state-home"
mkdir -p "${fake_root}/var/lib/soltros" "${state_home}"
jq -n '{oobe_required:false}' > "${fake_root}/var/lib/soltros/installation.json"
SOLTROS_ROOT="${fake_root}" XDG_STATE_HOME="${state_home}" \
  python3 "${oobe_root}/main.py" --automatic

printf 'PASS: native first-login OOBE is gated, typed, and cross-desktop\n'
