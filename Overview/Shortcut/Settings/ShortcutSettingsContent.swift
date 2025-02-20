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
    static let shortcutWindowTitles = InfoPopoverContent(
        title: "Multiple Window Titles",
        sections: [
            Section(
                title: "Entering Multiple Titles",
                text:
                    "You can specify multiple window titles for a single shortcut by separating them with commas."
            ),
            Section(
                title: "Title Matching",
                text:
                    "When activated, the shortcut will attempt to focus windows in the order they are listed."
            ),
            Section(
                title: "Example",
                text:
                    "Input: \"Overview, Project Notes, Design\"\nThis will first try to focus the 'Overview' window, then 'Project Notes', then 'Design'."
            ),
            Section(
                title: "Formatting Tips",
                text:
                    "• Separate titles with commas\n• Trim any extra spaces\n• Ensure window titles match exactly"
            ),
        ],
        isWarning: false
    )
}
