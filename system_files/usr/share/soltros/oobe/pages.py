from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Final

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Adw, Gdk, Gtk

from domain import TaskSpec

SPACE_XS: Final = 6
SPACE_SM: Final = 12
SPACE_MD: Final = 18
SPACE_XL: Final = 36


@dataclass(frozen=True, slots=True)
class IdentityPage:
    root: Adw.PreferencesPage
    git_name: Adw.EntryRow
    git_email: Adw.EntryRow
    shell: Adw.ComboRow
    setup_cli: Adw.SwitchRow


@dataclass(frozen=True, slots=True)
class SoftwarePage:
    root: Gtk.Widget
    banner: Adw.Banner
    recommended: Adw.SwitchRow
    gaming: Adw.SwitchRow
    development: Adw.SwitchRow
    multimedia: Adw.SwitchRow


@dataclass(frozen=True, slots=True)
class ExecutionPage:
    root: Gtk.Widget
    icon: Gtk.Image
    title: Gtk.Label
    description: Gtk.Label
    spinner: Gtk.Spinner
    progress: Gtk.ProgressBar
    scroller: Gtk.ScrolledWindow
    log: Gtk.TextBuffer


def build_welcome_page(brand_image: Path) -> Gtk.Widget:
    status = Adw.StatusPage()
    status.set_title("Welcome to SoltrOS Reborn")
    status.set_description(
        "Review your identity, preferred shell, and optional software before you start using the system."
    )
    if brand_image.is_file():
        status.set_paintable(Gdk.Texture.new_from_filename(str(brand_image)))
    else:
        status.set_icon_name("preferences-system-symbolic")
    status.set_margin_top(SPACE_XL)
    status.set_margin_bottom(SPACE_XL)
    clamp = Adw.Clamp(maximum_size=680, tightening_threshold=520)
    clamp.set_child(status)
    return clamp


def build_identity_page(selected_shell: int) -> IdentityPage:
    page = Adw.PreferencesPage()
    page.set_title("Identity and shell")
    page.set_description("These settings belong to your user account.")

    git_group = Adw.PreferencesGroup()
    git_group.set_title("Git identity")
    git_group.set_description("Optional. Both fields are required when either is entered.")
    git_name = Adw.EntryRow()
    git_name.set_title("Name")
    git_email = Adw.EntryRow()
    git_email.set_title("Email")
    git_group.add(git_name)
    git_group.add(git_email)
    page.add(git_group)

    shell_group = Adw.PreferencesGroup()
    shell_group.set_title("Terminal")
    shell = Adw.ComboRow()
    shell.set_title("Default shell")
    shell.set_subtitle("Changing the login shell requests administrator authentication.")
    shell.set_model(Gtk.StringList.new(["Keep current", "Bash", "Fish", "Zsh"]))
    shell.set_selected(selected_shell)
    setup_cli = Adw.SwitchRow()
    setup_cli.set_title("Install shell integrations")
    setup_cli.set_subtitle("Downloads checksum-verified Fish and command-line integrations.")
    shell_group.add(shell)
    shell_group.add(setup_cli)
    page.add(shell_group)
    return IdentityPage(page, git_name, git_email, shell, setup_cli)


def build_software_page() -> SoftwarePage:
    page_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
    banner = Adw.Banner.new(
        "Software profiles need an internet connection. You can finish offline and reopen this app later."
    )
    page_box.append(banner)

    page = Adw.PreferencesPage()
    page.set_vexpand(True)
    page.set_title("Software profiles")
    page.set_description("All downloads are optional and remain off until selected.")
    group = Adw.PreferencesGroup()
    group.set_title("Applications")

    recommended = Adw.SwitchRow()
    recommended.set_title("Recommended applications")
    recommended.set_subtitle("The complete curated SoltrOS Flatpak collection.")
    gaming = Adw.SwitchRow()
    gaming.set_title("Gaming")
    gaming.set_subtitle("Steam, Heroic, Bottles, Lutris, OBS Studio, and Discord.")
    development = Adw.SwitchRow()
    development.set_title("Development")
    development.set_subtitle("Editors, SDKs, IDEs, and Podman Desktop.")
    multimedia = Adw.SwitchRow()
    multimedia.set_title("Multimedia")
    multimedia.set_subtitle("Audio, video, graphics, and creative applications.")
    for row in (recommended, gaming, development, multimedia):
        group.add(row)
    page.add(group)
    page_box.append(page)
    return SoftwarePage(
        page_box,
        banner,
        recommended,
        gaming,
        development,
        multimedia,
    )


def build_review_page(tasks: tuple[TaskSpec, ...]) -> Adw.PreferencesPage:
    page = Adw.PreferencesPage()
    page.set_title("Review")
    page.set_description("Nothing starts until you apply these choices.")
    group = Adw.PreferencesGroup()
    group.set_title("Selected actions")
    if not tasks:
        row = Adw.ActionRow()
        row.set_title("No additional changes")
        row.set_subtitle(
            "You can finish setup now and reopen it from the application menu later."
        )
        row.add_prefix(Gtk.Image.new_from_icon_name("emblem-ok-symbolic"))
        group.add(row)
    for task in tasks:
        row = Adw.ActionRow()
        row.set_title(task.label)
        requirements: list[str] = []
        if task.requires_network:
            requirements.append("Internet")
        if task.may_authenticate:
            requirements.append("May request authentication")
        row.set_subtitle("; ".join(requirements) if requirements else "Local user setting")
        icon_name = (
            "network-transmit-receive-symbolic"
            if task.requires_network
            else "emblem-system-symbolic"
        )
        row.add_prefix(Gtk.Image.new_from_icon_name(icon_name))
        group.add(row)
    page.add(group)
    return page


def build_execution_page() -> ExecutionPage:
    page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=SPACE_SM)
    page.set_margin_start(SPACE_MD)
    page.set_margin_end(SPACE_MD)
    page.set_margin_top(SPACE_MD)
    page.set_margin_bottom(SPACE_MD)

    summary = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=SPACE_SM)
    icon = Gtk.Image.new_from_icon_name("system-run-symbolic")
    icon.set_pixel_size(32)
    icon.set_valign(Gtk.Align.CENTER)
    labels = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=SPACE_XS)
    labels.set_hexpand(True)
    title = Gtk.Label(label="Ready to apply setup", xalign=0, wrap=True)
    title.add_css_class("title-3")
    description = Gtk.Label(
        label="Selected tasks run one at a time and report their result here.",
        xalign=0,
        wrap=True,
    )
    description.add_css_class("dim-label")
    labels.append(title)
    labels.append(description)
    spinner = Gtk.Spinner()
    spinner.set_valign(Gtk.Align.CENTER)
    summary.append(icon)
    summary.append(labels)
    summary.append(spinner)

    progress = Gtk.ProgressBar(show_text=True)
    progress.set_hexpand(True)
    text_buffer = Gtk.TextBuffer()
    log = Gtk.TextView(buffer=text_buffer, editable=False, cursor_visible=False, monospace=True)
    log.set_wrap_mode(Gtk.WrapMode.WORD_CHAR)
    log.set_left_margin(SPACE_SM)
    log.set_right_margin(SPACE_SM)
    log.set_top_margin(SPACE_SM)
    log.set_bottom_margin(SPACE_SM)
    log.add_css_class("card")
    scroller = Gtk.ScrolledWindow(child=log, vexpand=True, min_content_height=180)
    page.append(summary)
    page.append(progress)
    page.append(scroller)
    return ExecutionPage(
        page,
        icon,
        title,
        description,
        spinner,
        progress,
        scroller,
        text_buffer,
    )
