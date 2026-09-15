/*
 Window/Settings/WindowSettingsContent.swift
 Overview

 Created by William Pierce on 1/13/25.
*/

extension InfoPopoverContent {
    static let windowAppearance = InfoPopoverContent(
        title: "Window Appearance",
        sections: [
            Section(
                title: "Opacity",
                text: "Controls preview window transparency"
            ),
            Section(
                title: "Default Dimensions",
                text:
                    "Sets initial dimensions for new preview windows. Windows can be resized while in Edit Mode."
            ),
            Section(
                title: "Shadows",
                text: "Adds shadows to preview windows"
            ),
            Section(
                title: "Synchronize Aspect Ratio",
                text:
                    "When enabled, selecting a source locks that preview’s resize handle to the source aspect ratio. You can still move and scale the window in Edit Mode; free resize returns when no source is assigned."
            ),
        ],
        isWarning: false
    )

    static let windowVisibility = InfoPopoverContent(
        title: "Window Visibility",
        sections: [
            Section(
                title: "Show Windows in Mission Control",
                text: "Show preview windows in Mission Control"
            ),
            Section(
                title: "Show Windows on All Desktops",
                text: "Show preview windows on all Spaces, including displays with a fullscreen game"
            ),
        ],
        isWarning: false
    )

    static let windowManagement = InfoPopoverContent(
        title: "Window Management",
        sections: [
            Section(
                title: "Always Create Window on Launch",
                text:
                    "Creates a preview window at on launch if none were restored from a previous session"
            ),
            Section(
                title: "Close Window with Preview Source",
                text: "Closes preview window when source window closes"
            ),
            Section(
                title: "Save Window Positions on Quit",
                text:
                    "Saves the position and size of each preview window when Overview is quit"
            ),
            Section(
                title: "Restore Window Positions on Launch",
                text:
                    "Restores the last saved preview window positions and sizes when Overview is launched"
            ),
        ],
        isWarning: false
    )
}
