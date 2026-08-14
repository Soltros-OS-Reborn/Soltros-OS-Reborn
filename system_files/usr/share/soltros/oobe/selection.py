from __future__ import annotations

from typing import Final

from domain import SetupSelection, ShellChoice, TaskSpec, build_tasks
from views import ViewBundle

SHELL_CHOICES: Final = (
    ShellChoice.KEEP,
    ShellChoice.BASH,
    ShellChoice.FISH,
    ShellChoice.ZSH,
)


def tasks_from_view(view: ViewBundle, username: str) -> tuple[TaskSpec, ...]:
    selected_shell = int(view.shell.get_selected())
    if not 0 <= selected_shell < len(SHELL_CHOICES):
        selected_shell = 0
    selection = SetupSelection(
        git_name=view.git_name.get_text(),
        git_email=view.git_email.get_text(),
        shell=SHELL_CHOICES[selected_shell],
        setup_cli=view.setup_cli.get_active(),
        recommended_apps=view.recommended_apps.get_active(),
        gaming_apps=view.gaming_apps.get_active(),
        development_apps=view.development_apps.get_active(),
        multimedia_apps=view.multimedia_apps.get_active(),
    )
    return build_tasks(selection, username)
