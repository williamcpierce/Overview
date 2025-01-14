/*
 Hotkey/Settings/HotkeySettingsContent.swift
 Overview
 
 Created by William Pierce on 1/13/25.
 
 Provides help content for hotkey-related settings.
*/

extension InfoPopoverContent {
    static let hotkeyActivation = InfoPopoverContent(
        title: "Source Window Activation Hotkeys",
        sections: [
            Section(
                title: "Hotkey Requirements",
                text: "Each hotkey must include:\n• At least one modifier key (⌘/⌥/⌃/⇧)\n• One additional character"
            ),
            Section(
                title: "Window Matching",
                text: "Hotkeys are matched to windows by their exact title. If multiple windows share the same title, behavior may be unpredictable."
            )
        ],
        isWarning: false
    )
}
