from __future__ import annotations

import gi

gi.require_version("Gtk", "4.0")
from gi.repository import GLib, Gtk


def _button_action(button: Gtk.Button) -> Gtk.CallbackAction:
    def activate(_widget: Gtk.Widget, _arguments: GLib.Variant | None) -> bool:
        if button.get_sensitive():
            button.activate()
        return True

    return Gtk.CallbackAction.new(activate)


def install_navigation_shortcuts(
    window: Gtk.Widget,
    back_button: Gtk.Button,
    next_button: Gtk.Button,
) -> None:
    controller = Gtk.ShortcutController()
    for accelerator, button in (
        ("<Alt>Left", back_button),
        ("<Alt>Right", next_button),
    ):
        trigger = Gtk.ShortcutTrigger.parse_string(accelerator)
        if trigger is not None:
            controller.add_shortcut(Gtk.Shortcut.new(trigger, _button_action(button)))
    window.add_controller(controller)
