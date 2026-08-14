from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Adw, Gtk

from pages import (
    build_execution_page,
    build_identity_page,
    build_software_page,
    build_welcome_page,
)


@dataclass(frozen=True, slots=True)
class ViewBundle:
    root: Adw.ToastOverlay
    toolbar: Adw.ToolbarView
    stack: Gtk.Stack
    window_title: Adw.WindowTitle
    stage_progress: Gtk.ProgressBar
    back_button: Gtk.Button
    skip_button: Gtk.Button
    next_button: Gtk.Button
    next_content: Adw.ButtonContent
    git_name: Adw.EntryRow
    git_email: Adw.EntryRow
    shell: Adw.ComboRow
    setup_cli: Adw.SwitchRow
    network_banner: Adw.Banner
    recommended_apps: Adw.SwitchRow
    gaming_apps: Adw.SwitchRow
    development_apps: Adw.SwitchRow
    multimedia_apps: Adw.SwitchRow
    execution_icon: Gtk.Image
    execution_title: Gtk.Label
    execution_description: Gtk.Label
    execution_spinner: Gtk.Spinner
    execution_progress: Gtk.ProgressBar
    execution_scroller: Gtk.ScrolledWindow
    execution_log: Gtk.TextBuffer

    def set_execution_status(self, icon: str, title: str, description: str) -> None:
        self.execution_icon.set_from_icon_name(icon)
        self.execution_title.set_label(title)
        self.execution_description.set_label(description)

    def set_execution_complete(self, icon: str, title: str, description: str) -> None:
        self.set_execution_status(icon, title, description)
        self.execution_title.remove_css_class("title-3")
        self.execution_title.add_css_class("title-1")


def _button(label: str, icon_name: str) -> tuple[Gtk.Button, Adw.ButtonContent]:
    content = Adw.ButtonContent()
    content.set_label(label)
    content.set_icon_name(icon_name)
    return Gtk.Button(child=content), content


def build_view(variant_name: str, selected_shell: int, brand_image: Path) -> ViewBundle:
    stack = Gtk.Stack(
        transition_type=Gtk.StackTransitionType.SLIDE_LEFT_RIGHT,
        transition_duration=220,
        vexpand=True,
        hexpand=True,
    )
    stack.add_named(build_welcome_page(brand_image), "welcome")
    identity = build_identity_page(selected_shell)
    stack.add_named(identity.root, "identity")
    software = build_software_page()
    stack.add_named(software.root, "software")
    execution = build_execution_page()
    stack.add_named(execution.root, "execution")

    title = Adw.WindowTitle(title="Welcome to SoltrOS", subtitle=variant_name)
    header = Adw.HeaderBar()
    header.set_title_widget(title)
    stage_progress = Gtk.ProgressBar(fraction=0.2)
    top = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
    top.append(header)
    top.append(stage_progress)

    back, _ = _button("Back", "go-previous-symbolic")
    skip, _ = _button("Set Up Later", "document-save-symbolic")
    next_button, next_content = _button("Continue", "go-next-symbolic")
    next_button.add_css_class("suggested-action")
    action_bar = Gtk.ActionBar()
    action_bar.pack_start(back)
    action_bar.set_center_widget(skip)
    action_bar.pack_end(next_button)

    toolbar = Adw.ToolbarView()
    toolbar.add_top_bar(top)
    toolbar.set_content(stack)
    toolbar.add_bottom_bar(action_bar)
    overlay = Adw.ToastOverlay()
    overlay.set_child(toolbar)
    return ViewBundle(
        root=overlay,
        toolbar=toolbar,
        stack=stack,
        window_title=title,
        stage_progress=stage_progress,
        back_button=back,
        skip_button=skip,
        next_button=next_button,
        next_content=next_content,
        git_name=identity.git_name,
        git_email=identity.git_email,
        shell=identity.shell,
        setup_cli=identity.setup_cli,
        network_banner=software.banner,
        recommended_apps=software.recommended,
        gaming_apps=software.gaming,
        development_apps=software.development,
        multimedia_apps=software.multimedia,
        execution_icon=execution.icon,
        execution_title=execution.title,
        execution_description=execution.description,
        execution_spinner=execution.spinner,
        execution_progress=execution.progress,
        execution_scroller=execution.scroller,
        execution_log=execution.log,
    )
