from __future__ import annotations

import os
import pwd
from pathlib import Path
from typing import assert_never
import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Adw, Gio, GLib, Gtk

from domain import (
    SelectionError,
    TaskSpec,
    load_system_profile,
    write_completion,
)
from executor import EventKind, ExecutionEvent, TaskExecutor, TaskResult
from navigation import PAGE_NAMES, PAGE_TITLES
from pages import build_review_page
from selection import tasks_from_view
from shortcuts import install_navigation_shortcuts
from views import build_view


class SetupWindow(Adw.ApplicationWindow):
    def __init__(self, application: Adw.Application, root: Path, state_file: Path) -> None:
        super().__init__(application=application)
        self.set_title("Welcome to SoltrOS Reborn")
        self.set_default_size(760, 620)
        self.set_size_request(480, 520)

        account = pwd.getpwuid(os.getuid())
        self._username = account.pw_name
        profile = load_system_profile(root)
        brand_image = Path(
            os.environ.get(
                "SOLTROS_BRAND_IMAGE",
                str(root / "usr" / "share" / "plymouth" / "themes" / "spinner" / "watermark.png"),
            )
        )
        self._state_file = state_file
        self._view = build_view(profile.variant_name, 0, brand_image)
        self.set_content(self._view.root)

        self._executor = TaskExecutor()
        self._page_index = 0
        self._review_page: Gtk.Widget | None = None
        self._selected_tasks: tuple[TaskSpec, ...] = ()
        self._active_tasks: tuple[TaskSpec, ...] = ()
        self._failed_tasks: tuple[TaskSpec, ...] = ()
        self._completed_count = 0
        self._setup_completed = False

        self._view.back_button.connect("clicked", self._on_back)
        self._view.skip_button.connect("clicked", self._on_defer)
        self._view.next_button.connect("clicked", self._on_next)
        self.connect("close-request", self._on_close_request)

        monitor = Gio.NetworkMonitor.get_default()
        monitor.connect("network-changed", self._on_network_changed)
        self._set_network_available(monitor.get_network_available())
        install_navigation_shortcuts(
            self,
            self._view.back_button,
            self._view.next_button,
        )
        self._show_page(0)

    def _on_network_changed(self, _monitor: Gio.NetworkMonitor, available: bool) -> None:
        self._set_network_available(available)

    def _set_network_available(self, available: bool) -> None:
        self._view.network_banner.set_revealed(not available)
        for row in (
            self._view.setup_cli,
            self._view.recommended_apps,
            self._view.gaming_apps,
            self._view.development_apps,
            self._view.multimedia_apps,
        ):
            row.set_sensitive(available)
            if not available:
                row.set_active(False)

    def _validated_tasks(self) -> tuple[TaskSpec, ...] | None:
        try:
            return tasks_from_view(self._view, self._username)
        except SelectionError as error:
            self._toast(str(error))
            return None

    def _replace_review(self, tasks: tuple[TaskSpec, ...]) -> None:
        if self._review_page is not None:
            self._view.stack.remove(self._review_page)
        self._review_page = build_review_page(tasks)
        self._view.stack.add_named(self._review_page, "review")

    def _show_page(self, index: int) -> None:
        self._page_index = index
        self._view.stack.set_visible_child_name(PAGE_NAMES[index])
        self._view.window_title.set_title(PAGE_TITLES[index])
        self._view.stage_progress.set_fraction((index + 1) / len(PAGE_NAMES))
        self._view.back_button.set_sensitive(index > 0 and index < 4)
        self._view.skip_button.set_visible(index < 4)
        self._view.next_button.set_sensitive(True)
        if index == 3:
            self._view.next_content.set_label("Apply Setup")
            self._view.next_content.set_icon_name("system-run-symbolic")
        else:
            self._view.next_content.set_label("Continue")
            self._view.next_content.set_icon_name("go-next-symbolic")

    def _on_back(self, _button: Gtk.Button) -> None:
        if self._page_index > 0:
            self._show_page(self._page_index - 1)

    def _on_next(self, _button: Gtk.Button) -> None:
        if self._page_index == 4:
            if self._setup_completed:
                self.close()
            elif self._failed_tasks:
                self._start_tasks(self._failed_tasks)
            return
        if self._page_index == 1 and self._validated_tasks() is None:
            return
        if self._page_index == 2:
            tasks = self._validated_tasks()
            if tasks is None:
                return
            self._selected_tasks = tasks
            self._replace_review(tasks)
        if self._page_index == 3:
            self._start_tasks(self._selected_tasks)
            return
        self._show_page(self._page_index + 1)

    def _start_tasks(self, tasks: tuple[TaskSpec, ...]) -> None:
        self._active_tasks = tasks
        self._failed_tasks = ()
        self._completed_count = 0
        self._show_page(4)
        self._view.skip_button.set_visible(False)
        self._view.next_button.set_sensitive(False)
        self._view.execution_spinner.start()
        self._view.set_execution_status(
            "system-run-symbolic",
            "Applying your choices",
            "Keep this window open while setup is running.",
        )
        self._view.execution_progress.set_fraction(0.0)
        self._view.execution_progress.set_text("Starting")
        self._view.execution_scroller.set_visible(bool(tasks))
        if not tasks:
            write_completion(self._state_file, "completed", [])
            self._finish_success()
            return
        self._executor.start(tasks, self._queue_event, self._queue_completion)

    def _queue_event(self, event: ExecutionEvent) -> None:
        GLib.idle_add(self._handle_event, event)

    def _queue_completion(self, results: tuple[TaskResult, ...]) -> None:
        GLib.idle_add(self._handle_completion, results)

    def _append_log(self, message: str) -> None:
        end = self._view.execution_log.get_end_iter()
        self._view.execution_log.insert(end, message + "\n")

    def _handle_event(self, event: ExecutionEvent) -> bool:
        match event.kind:
            case EventKind.STARTED:
                self._view.execution_description.set_label(event.label)
                self._append_log(f"> {event.label}")
            case EventKind.OUTPUT:
                self._append_log(f"  {event.message}")
            case EventKind.FINISHED:
                self._completed_count += 1
                success = event.success is True
                self._append_log(f"{'OK' if success else 'FAILED'} {event.label}")
                fraction = self._completed_count / max(len(self._active_tasks), 1)
                self._view.execution_progress.set_fraction(fraction)
                self._view.execution_progress.set_text(
                    f"{self._completed_count} of {len(self._active_tasks)}"
                )
            case unreachable:
                assert_never(unreachable)
        return False

    def _handle_completion(self, results: tuple[TaskResult, ...]) -> bool:
        self._view.execution_spinner.stop()
        failed_ids = {result.task_id for result in results if not result.success}
        self._failed_tasks = tuple(
            task for task in self._active_tasks if task.task_id in failed_ids
        )
        if self._failed_tasks:
            self._view.set_execution_status(
                "dialog-warning-symbolic",
                "Some steps need attention",
                "Review the output, correct the cause, and retry the failed steps."
            )
            self._view.next_content.set_label("Retry Failed")
            self._view.next_content.set_icon_name("view-refresh-symbolic")
            self._view.next_button.set_sensitive(True)
            self._view.skip_button.set_visible(True)
            return False
        write_completion(
            self._state_file,
            "completed",
            [task.task_id for task in self._selected_tasks],
        )
        self._finish_success()
        return False

    def _finish_success(self) -> None:
        self._setup_completed = True
        self._view.execution_spinner.stop()
        self._view.set_execution_complete(
            "emblem-ok-symbolic",
            "Your system is ready",
            "Setup will not open automatically again. You can reopen it from the application menu.",
        )
        self._view.execution_progress.set_fraction(1.0)
        self._view.execution_progress.set_text("Complete")
        self._view.next_content.set_label("Finish")
        self._view.next_content.set_icon_name("window-close-symbolic")
        self._view.next_button.set_sensitive(True)
        self._view.skip_button.set_visible(False)

    def _on_defer(self, _button: Gtk.Button) -> None:
        dialog = Adw.AlertDialog.new(
            "Finish setup later?",
            "Automatic setup will stop, but you can reopen Welcome to SoltrOS from the application menu.",
        )
        dialog.add_response("cancel", "Keep Setting Up")
        dialog.add_response("defer", "Set Up Later")
        dialog.set_close_response("cancel")
        dialog.set_default_response("cancel")
        dialog.set_response_appearance("defer", Adw.ResponseAppearance.SUGGESTED)
        dialog.choose(self, None, self._on_defer_response)

    def _on_defer_response(self, dialog: Adw.AlertDialog, result: Gio.AsyncResult) -> None:
        if dialog.choose_finish(result) != "defer":
            return
        write_completion(
            self._state_file,
            "deferred",
            [task.task_id for task in self._selected_tasks],
        )
        self.close()

    def _on_close_request(self, _window: Gtk.Window) -> bool:
        if self._executor.running:
            self._toast("Setup is still running. Wait for the current tasks to finish.")
            return True
        return False

    def _toast(self, message: str) -> None:
        self._view.root.add_toast(Adw.Toast.new(message))
