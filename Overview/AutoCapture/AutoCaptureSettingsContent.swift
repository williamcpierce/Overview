/*
 AutoCapture/Settings/AutoCaptureSettingsContent.swift
 Overview

 Created by William Pierce on 2/25/25.

 Provides help content for auto-capture related settings.
*/

extension InfoPopoverContent {
    static let autoCapture = InfoPopoverContent(
        title: "Auto-Capture",
        sections: [
            Section(
                title: "Summary",
                text: "Automatically create preview windows for specific applications like EVE Online."
            ),
            Section(
                title: "EVE Online Support",
                text: "Detects when EVE character windows appear and creates preview windows automatically. Remembers window positions for each specific character."
            ),
            Section(
                title: "Character Detection",
                text: "Waits for window titles to change from \"EVE\" to \"EVE - Character Name\" before creating previews, ensuring each character gets its own preview window."
            ),
            Section(
                title: "Application List",
                text: "Customize which applications trigger auto-capture. EVE Online is included by default."
            ),
            Section(
                title: "Position Memory",
                text: "Preview window positions are remembered for each character, so they'll appear in the same place when you log in again."
            )
        ],
        isWarning: false
    )
}
