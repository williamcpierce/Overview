/*
 Shortcut/Settings/ShortcutSettingsContent.swift
 Overview

 Created by William Pierce on 1/13/25.
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
