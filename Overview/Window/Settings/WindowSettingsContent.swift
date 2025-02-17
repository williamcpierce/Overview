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

    static let windowBehavior = InfoPopoverContent(
        title: "Window Behavior",
        sections: [
            Section(
                title: "Show Windows in Mission Control",
                text: "Show preview windows in Mission Control"
            ),
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
                title: "Show Windows on All Desktops",
                text: "Show preview windows on all desktops"
            ),
        ],
        isWarning: false
    )
}
