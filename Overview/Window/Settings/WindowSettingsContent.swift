/*
 Window/Settings/WindowSettingsContent.swift
 Overview

 Created by William Pierce on 1/13/25.

 Provides help content for window-related settings.
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
                title: "Shadows",
                text: "Adds shadows to preview windows"
            ),
            Section(
                title: "Default Dimensions",
                text:
                    "Sets initial dimensions for new windows. Windows can be resized while in Edit Mode."
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
                text: "Show preview windows on all desktops, including over fullscreen windows"
            ),
        ],
        isWarning: false
    )

    static let windowManagement = InfoPopoverContent(
        title: "Window Management",
        sections: [
            Section(
                title: "Create Window on Launch",
                text:
                    "Opens a preview window at startup if none were restored from a previous session"
            ),
            Section(
                title: "Close Window with Preview Source",
                text: "Closes preview window when source window closes"
            ),
            Section(
                title: "Save Window Positions on Quit",
                text:
                    "Saves the position and size of each Overview window on app quit, to be restored on app launch"
            ),
        ],
        isWarning: false
    )
}
