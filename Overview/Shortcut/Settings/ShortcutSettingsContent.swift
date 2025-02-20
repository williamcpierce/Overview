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
            Section(
                title: "Window Cycling",
                text:
                    "When using shortcuts with multiple window titles, pressing the shortcut repeatedly will cycle through the windows in order. If one of the windows in the list is currently active, cycling will start from the next window in the sequence."
            ),
            Section(
                title: "How Activation Works",
                text:
                    "Overview activates applications rather than specific windows. It uses window titles to determine which application to bring to the front. Once an application is activated, macOS determines which window becomes active based on the application's window ordering."
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
                    "When activated, the shortcut cycles through windows in the order they are listed. If one of the windows is currently active, cycling starts from the next window in the list."
            ),
            Section(
                title: "Application Activation",
                text:
                    "Note that shortcuts activate applications, not specific windows. Overview looks for window titles to determine which application to activate, but the application itself decides which window becomes active. This means that if an application has multiple windows open, the most recently used window may become active rather than the specific window whose title matched."
            ),
            Section(
                title: "Example",
                text:
                    "Input: \"Overview, Project Notes, Design\"\nWith \"Project Notes\" active, pressing the shortcut will focus \"Design\", and pressing it again will focus \"Overview\"."
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
