/*
 Shortcut/Settings/ShortcutSettingsContent.swift
 Overview

 Created by William Pierce on 1/13/25.

 Provides help content for keyboard shortcut-related settings.
*/

extension InfoPopoverContent {
    static let shortcutActivation = InfoPopoverContent(
        title: "Source Window Activation Keyboard Shortcuts",
        sections: [
            Section(
                title: "Keyboard Shortcut Requirements",
                text:
                    "Each keyboard shortcut must include:\n• At least one modifier key (⌘/⌥/⌃/⇧)\n• One additional character"
            ),
            Section(
                title: "Window Matching",
                text:
                    "Keyboard shortcuts are matched to windows by their exact title. If multiple windows share the same title, behavior may be unpredictable."
            ),
        ],
        isWarning: false
    )
}
