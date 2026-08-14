from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path
from typing import Final

from domain import automatic_setup_required, default_state_file

APPLICATION_ID: Final = "org.soltros.Welcome"


def _arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(prog="soltros-welcome")
    parser.add_argument(
        "--automatic",
        action="store_true",
        help="open only when the installer requested first-login setup",
    )
    parser.add_argument("--version", action="version", version="SoltrOS Welcome 1")
    return parser.parse_args()


def main() -> int:
    arguments = _arguments()
    root = Path(os.environ.get("SOLTROS_ROOT", "/"))
    state_file = default_state_file()
    if arguments.automatic and not automatic_setup_required(root, state_file):
        return 0

    import gi

    gi.require_version("Gtk", "4.0")
    gi.require_version("Adw", "1")
    from gi.repository import Adw, Gio

    from window import SetupWindow

    class SetupApplication(Adw.Application):
        def __init__(self) -> None:
            super().__init__(
                application_id=APPLICATION_ID,
                flags=Gio.ApplicationFlags.DEFAULT_FLAGS,
            )
            self._window: SetupWindow | None = None

        def do_activate(self) -> None:
            if self._window is None:
                self._window = SetupWindow(self, root, state_file)
            self._window.present()

    application = SetupApplication()
    return int(application.run([sys.argv[0]]))


if __name__ == "__main__":
    raise SystemExit(main())
